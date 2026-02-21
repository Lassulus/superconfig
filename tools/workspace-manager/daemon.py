#!/usr/bin/env python3
"""
Workspace Manager Daemon

A compositor-agnostic workspace manager that:
- Subscribes to sway IPC for workspace change events
- Runs user-defined hooks on workspace enter/leave
- Provides current workspace and directory info via Unix socket

Config merging: user config is loaded first, then system config (declarative) overrides per-field
"""

from __future__ import annotations

import asyncio
import json
import os
import signal
import subprocess
import sys
from pathlib import Path
from typing import Any

# XDG runtime directory for socket and state
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
SOCKET_DIR = RUNTIME_DIR / "workspace-manager"
SOCKET_PATH = SOCKET_DIR / "socket"
STATE_PATH = SOCKET_DIR / "state.json"

# System config directory (declarative, takes precedence)
_system_config_dir_env = os.environ.get("WORKSPACE_MANAGER_SYSTEM_CONFIG_DIR")
SYSTEM_CONFIG_DIR: Path | None = (
    Path(_system_config_dir_env).expanduser() if _system_config_dir_env else None
)

# User config directory (fallback)
_config_dir_env = os.environ.get("WORKSPACE_MANAGER_CONFIG_DIR")
CONFIG_DIR = (
    Path(_config_dir_env).expanduser()
    if _config_dir_env
    else Path.home() / "workspaces"
)

_default_dir_env = os.environ.get("WORKSPACE_MANAGER_DEFAULT_DIR")
DEFAULT_DIRECTORY = (
    Path(_default_dir_env).expanduser() if _default_dir_env else Path.home()
)

TERMINAL_COMMAND = os.environ.get("WORKSPACE_MANAGER_TERMINAL", "kitty")


def load_config_file(config_file: Path) -> dict[str, Any] | None:
    """Load a workspace config file, returning None if it doesn't exist or fails."""
    if not config_file.exists():
        return None
    try:
        with open(config_file) as f:
            return json.load(f)  # type: ignore[no-any-return]
    except (json.JSONDecodeError, OSError) as e:
        print(f"Warning: Failed to load config {config_file}: {e}", file=sys.stderr)
        return None


class WorkspaceConfig:
    """Configuration for a workspace.

    Merges user config with system config (declarative).
    System config fields take precedence over user config fields.
    """

    def __init__(self, name: str) -> None:
        self.name = name
        self.directory: Path = DEFAULT_DIRECTORY
        self.on_enter: list[str] = []
        self.on_leave: list[str] = []
        self.on_create: list[str] = []
        self._load()

    def _load(self) -> None:
        # Load user config first (base)
        user_config_file = CONFIG_DIR / f"{self.name}.json"
        user_data = load_config_file(user_config_file)

        # Load system config (declarative, takes precedence)
        system_data: dict[str, Any] | None = None
        if SYSTEM_CONFIG_DIR is not None:
            system_config_file = SYSTEM_CONFIG_DIR / f"{self.name}.json"
            system_data = load_config_file(system_config_file)

        # Merge: start with user config, override with system config
        merged: dict[str, Any] = {}
        if user_data is not None:
            merged.update(user_data)
        if system_data is not None:
            merged.update(system_data)

        # Apply merged config
        if "directory" in merged:
            self.directory = Path(str(merged["directory"])).expanduser()
        if "on_enter" in merged:
            self.on_enter = list(merged["on_enter"])
        if "on_leave" in merged:
            self.on_leave = list(merged["on_leave"])
        if "on_create" in merged:
            self.on_create = list(merged["on_create"])


class WorkspaceManager:
    """Manages workspace state and configuration"""

    def __init__(self) -> None:
        self.current_workspace: str | None = None
        self.configs: dict[str, WorkspaceConfig] = {}
        self.created_workspaces: set[str] = set()

    def get_config(self, workspace: str) -> WorkspaceConfig:
        """Get or create config for a workspace (configs are loaded fresh each time)"""
        # Always reload config to pick up changes
        self.configs[workspace] = WorkspaceConfig(workspace)
        return self.configs[workspace]

    def get_current_directory(self) -> Path:
        """Get the directory for the current workspace"""
        if self.current_workspace:
            config = self.get_config(self.current_workspace)
            return config.directory
        return DEFAULT_DIRECTORY

    def _tmux_session_exists(self, session_name: str) -> bool:
        """Check if a tmux session already exists"""
        try:
            result = subprocess.run(
                ["tmux", "has-session", "-t", session_name],
                capture_output=True,
            )
            return result.returncode == 0
        except FileNotFoundError:
            print("Warning: tmux not found", file=sys.stderr)
            return False

    async def _run_on_create(self, workspace: str, config: WorkspaceConfig) -> None:
        """Start on_create commands each in their own tmux session + terminal.

        For each command, creates a tmux session named <workspace>-start<N>
        running the command, then opens a terminal window attached to it.
        If the terminal is closed, reattach with: tmux attach -t <workspace>-start<N>
        """
        if not config.on_create:
            return

        work_dir = str(config.directory)

        for i, cmd in enumerate(config.on_create, start=1):
            session_name = f"{workspace}-start{i}"

            # Skip if tmux session already exists (e.g. from a previous run)
            if self._tmux_session_exists(session_name):
                print(
                    f"Tmux session '{session_name}' already exists, skipping",
                    file=sys.stderr,
                )
                continue

            # Create a detached tmux session running the command
            try:
                subprocess.run(
                    [
                        "tmux",
                        "new-session",
                        "-d",
                        "-s",
                        session_name,
                        "-c",
                        work_dir,
                        cmd,
                    ],
                    check=True,
                )
                print(
                    f"Created tmux session '{session_name}': {cmd}",
                    file=sys.stderr,
                )
            except (OSError, subprocess.CalledProcessError) as e:
                print(
                    f"Failed to create tmux session '{session_name}': {e}",
                    file=sys.stderr,
                )
                continue

            # Open a terminal window attached to the tmux session
            try:
                subprocess.Popen(
                    [
                        TERMINAL_COMMAND,
                        "-T",
                        session_name,
                        "tmux",
                        "attach",
                        "-t",
                        session_name,
                    ],
                    start_new_session=True,
                )
                print(
                    f"Opened terminal for tmux session '{session_name}'",
                    file=sys.stderr,
                )
            except OSError as e:
                print(
                    f"Failed to open terminal for '{session_name}': {e}",
                    file=sys.stderr,
                )

    async def handle_workspace_change(
        self, old_workspace: str | None, new_workspace: str
    ) -> None:
        """Handle a workspace focus change event"""
        # Run on_leave hooks for old workspace
        if old_workspace:
            old_config = self.get_config(old_workspace)
            for hook in old_config.on_leave:
                await self._run_hook(hook, "on_leave", old_workspace)

        # Update current workspace
        self.current_workspace = new_workspace

        # Run on_create hooks if this is the first time entering the workspace
        new_config = self.get_config(new_workspace)
        if new_workspace not in self.created_workspaces:
            self.created_workspaces.add(new_workspace)
            await self._run_on_create(new_workspace, new_config)

        # Run on_enter hooks for new workspace
        for hook in new_config.on_enter:
            await self._run_hook(hook, "on_enter", new_workspace)

        # Write state file
        self._write_state()

    async def _run_hook(self, command: str, hook_type: str, workspace: str) -> None:
        """Run a hook command in the background"""
        try:
            # Run in background, don't wait
            subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            print(f"Ran {hook_type} hook for {workspace}: {command}", file=sys.stderr)
        except OSError as e:
            print(
                f"Failed to run {hook_type} hook for {workspace}: {e}",
                file=sys.stderr,
            )

    def _write_state(self) -> None:
        """Write current state to state file"""
        state: dict[str, Any] = {
            "workspace": self.current_workspace,
            "directory": str(self.get_current_directory()),
        }
        try:
            STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
            with open(STATE_PATH, "w") as f:
                json.dump(state, f)
        except OSError as e:
            print(f"Failed to write state file: {e}", file=sys.stderr)


manager = WorkspaceManager()


async def subscribe_sway() -> None:
    """Subscribe to sway IPC workspace events"""
    print("Starting sway workspace subscription...", file=sys.stderr)

    while True:
        try:
            proc = await asyncio.create_subprocess_exec(
                "swaymsg",
                "-t",
                "subscribe",
                "-m",
                '["workspace"]',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            if proc.stdout is None:
                print("Failed to get stdout from swaymsg", file=sys.stderr)
                await asyncio.sleep(5)
                continue

            async for line in proc.stdout:
                try:
                    event: dict[str, Any] = json.loads(line.decode().strip())
                    if event.get("change") == "focus":
                        current: dict[str, Any] = event.get("current", {})
                        old: dict[str, Any] | None = event.get("old")
                        new_name: str | None = current.get("name")
                        old_name: str | None = old.get("name") if old else None

                        if new_name:
                            print(
                                f"Workspace change: {old_name} -> {new_name}",
                                file=sys.stderr,
                            )
                            await manager.handle_workspace_change(old_name, new_name)
                except json.JSONDecodeError as e:
                    print(f"Failed to parse sway event: {e}", file=sys.stderr)

            # If swaymsg exits, wait a bit and retry
            await proc.wait()
            print("swaymsg exited, retrying in 5 seconds...", file=sys.stderr)
            await asyncio.sleep(5)

        except FileNotFoundError:
            print("swaymsg not found, retrying in 10 seconds...", file=sys.stderr)
            await asyncio.sleep(10)
        except Exception as e:
            print(
                f"Error in sway subscription: {e}, retrying in 5 seconds...",
                file=sys.stderr,
            )
            await asyncio.sleep(5)


async def handle_client(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    """Handle a client connection to the Unix socket"""
    try:
        data = await reader.read(1024)
        command = data.decode().strip()

        response: dict[str, Any]
        if command == "dir":
            response = {"directory": str(manager.get_current_directory())}
        elif command == "workspace":
            response = {"workspace": manager.current_workspace}
        elif command == "status":
            response = {
                "workspace": manager.current_workspace,
                "directory": str(manager.get_current_directory()),
                "running": True,
            }
        else:
            response = {"error": f"Unknown command: {command}"}

        writer.write(json.dumps(response).encode() + b"\n")
        await writer.drain()
    except Exception as e:
        print(f"Error handling client: {e}", file=sys.stderr)
    finally:
        writer.close()
        await writer.wait_closed()


async def socket_server() -> None:
    """Run the Unix socket server for CLI queries"""
    # Ensure socket directory exists
    SOCKET_DIR.mkdir(parents=True, exist_ok=True)

    # Remove stale socket if exists
    if SOCKET_PATH.exists():
        SOCKET_PATH.unlink()

    server = await asyncio.start_unix_server(handle_client, path=str(SOCKET_PATH))

    # Make socket accessible
    os.chmod(SOCKET_PATH, 0o600)

    print(f"Socket server listening on {SOCKET_PATH}", file=sys.stderr)

    async with server:
        await server.serve_forever()


async def get_current_workspace() -> str | None:
    """Get the current workspace from sway"""
    try:
        proc = await asyncio.create_subprocess_exec(
            "swaymsg",
            "-t",
            "get_workspaces",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        workspaces: list[dict[str, Any]] = json.loads(stdout.decode())
        for ws in workspaces:
            if ws.get("focused"):
                name = ws.get("name")
                return str(name) if name is not None else None
    except Exception as e:
        print(f"Failed to get current workspace: {e}", file=sys.stderr)
    return None


async def main() -> None:
    """Main entry point"""
    # Ensure user config directory exists (system config is read-only from nix store)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    # Log config directories
    if SYSTEM_CONFIG_DIR:
        print(f"System config dir: {SYSTEM_CONFIG_DIR}", file=sys.stderr)
    print(f"User config dir: {CONFIG_DIR}", file=sys.stderr)

    # Get initial workspace
    initial_workspace = await get_current_workspace()
    if initial_workspace:
        manager.current_workspace = initial_workspace
        manager._write_state()
        print(f"Initial workspace: {initial_workspace}", file=sys.stderr)

    # Handle shutdown gracefully
    loop = asyncio.get_event_loop()

    def shutdown(sig: signal.Signals) -> None:
        print(f"Received {sig.name}, shutting down...", file=sys.stderr)
        for task in asyncio.all_tasks(loop):
            task.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, shutdown, sig)

    # Run both tasks concurrently
    try:
        await asyncio.gather(
            subscribe_sway(),
            socket_server(),
        )
    except asyncio.CancelledError:
        print("Shutdown complete", file=sys.stderr)
    finally:
        # Cleanup socket
        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()


if __name__ == "__main__":
    asyncio.run(main())
