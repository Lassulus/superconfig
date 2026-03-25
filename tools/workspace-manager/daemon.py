#!/usr/bin/env python3
"""
Workspace Manager Daemon

Tracks the current sway workspace and provides:
- Current workspace name and directory via Unix socket
- Workspace change events to subscribers

Config: ~/workspaces/<name>.json with at minimum {"directory": "..."}
System config (from Nix) takes precedence over user config.
"""

from __future__ import annotations

import asyncio
import json
import os
import signal
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


def get_workspace_directory(name: str) -> Path:
    """Get the directory for a workspace by merging user and system config."""
    merged: dict[str, Any] = {}

    user_data = load_config_file(CONFIG_DIR / f"{name}.json")
    if user_data is not None:
        merged.update(user_data)

    if SYSTEM_CONFIG_DIR is not None:
        system_data = load_config_file(SYSTEM_CONFIG_DIR / f"{name}.json")
        if system_data is not None:
            merged.update(system_data)

    if "directory" in merged:
        return Path(str(merged["directory"])).expanduser()
    return DEFAULT_DIRECTORY


class WorkspaceManager:
    """Tracks current workspace state."""

    def __init__(self) -> None:
        self.current_workspace: str | None = None

    def get_current_directory(self) -> Path:
        if self.current_workspace:
            return get_workspace_directory(self.current_workspace)
        return DEFAULT_DIRECTORY

    def handle_workspace_change(
        self, old_workspace: str | None, new_workspace: str
    ) -> None:
        self.current_workspace = new_workspace
        self._write_state()

    def _write_state(self) -> None:
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

# Subscribers: list of (StreamWriter, Event) tuples
subscribers: list[tuple[asyncio.StreamWriter, asyncio.Event]] = []


async def notify_subscribers(old_workspace: str | None, new_workspace: str) -> None:
    """Notify all subscribers of a workspace change."""
    event = (
        json.dumps(
            {
                "event": "workspace_change",
                "old": old_workspace,
                "new": new_workspace,
            }
        ).encode()
        + b"\n"
    )
    for writer, done in subscribers:
        try:
            writer.write(event)
            await writer.drain()
        except (OSError, ConnectionResetError):
            done.set()


async def subscribe_sway() -> None:
    """Subscribe to sway IPC workspace events."""
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
                            manager.handle_workspace_change(old_name, new_name)
                            await notify_subscribers(old_name, new_name)
                except json.JSONDecodeError as e:
                    print(f"Failed to parse sway event: {e}", file=sys.stderr)

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


def load_user_config(workspace: str) -> dict[str, Any]:
    """Load user workspace config, returning empty dict if not found."""
    config_file = CONFIG_DIR / f"{workspace}.json"
    return load_config_file(config_file) or {}


def save_user_config(workspace: str, updates: dict[str, Any]) -> bool:
    """Merge updates into user workspace config and write to disk."""
    config_file = CONFIG_DIR / f"{workspace}.json"
    try:
        existing = load_user_config(workspace)
        existing.update(updates)
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(config_file, "w") as f:
            json.dump(existing, f, indent=2)
        return True
    except OSError as e:
        print(f"Failed to save config for {workspace}: {e}", file=sys.stderr)
        return False


async def handle_client(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    """Handle a client connection to the Unix socket."""
    try:
        data = await reader.read(65536)
        raw = data.decode().strip()

        response: dict[str, Any]

        # Try JSON command first, fall back to simple text commands
        msg: dict[str, Any] | None = None
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            pass

        if msg is not None:
            cmd = msg.get("cmd", "")
            if cmd == "save-tabs":
                workspace = msg.get("workspace", "")
                tabs: list[Any] = msg.get("tabs", [])
                if workspace:
                    ok = save_user_config(workspace, {"tabs": tabs})
                    response = {"ok": ok}
                else:
                    response = {"ok": False, "error": "No workspace specified"}
            elif cmd == "get-tabs":
                workspace = msg.get("workspace", "")
                if workspace:
                    config = load_user_config(workspace)
                    response = {"tabs": config.get("tabs", [])}
                else:
                    response = {"tabs": []}
            else:
                response = {"error": f"Unknown JSON command: {cmd}"}
        elif raw == "subscribe":
            done = asyncio.Event()
            subscribers.append((writer, done))
            print("New subscriber connected", file=sys.stderr)
            try:
                await done.wait()
            except asyncio.CancelledError:
                pass
            finally:
                subscribers[:] = [(w, d) for w, d in subscribers if w is not writer]
                print("Subscriber disconnected", file=sys.stderr)
            return
        elif raw == "dir":
            response = {"directory": str(manager.get_current_directory())}
        elif raw == "workspace":
            response = {"workspace": manager.current_workspace}
        elif raw == "status":
            response = {
                "workspace": manager.current_workspace,
                "directory": str(manager.get_current_directory()),
                "running": True,
            }
        else:
            response = {"error": f"Unknown command: {raw}"}

        writer.write(json.dumps(response).encode() + b"\n")
        await writer.drain()
    except Exception as e:
        print(f"Error handling client: {e}", file=sys.stderr)
    finally:
        writer.close()
        await writer.wait_closed()


async def socket_server() -> None:
    """Run the Unix socket server."""
    SOCKET_DIR.mkdir(parents=True, exist_ok=True)

    if SOCKET_PATH.exists():
        SOCKET_PATH.unlink()

    server = await asyncio.start_unix_server(handle_client, path=str(SOCKET_PATH))
    os.chmod(SOCKET_PATH, 0o600)

    print(f"Socket server listening on {SOCKET_PATH}", file=sys.stderr)

    async with server:
        await server.serve_forever()


async def get_current_workspace() -> str | None:
    """Get the current workspace from sway."""
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
    """Main entry point."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    if SYSTEM_CONFIG_DIR:
        print(f"System config dir: {SYSTEM_CONFIG_DIR}", file=sys.stderr)
    print(f"User config dir: {CONFIG_DIR}", file=sys.stderr)

    # Register sway rule to hide Firefox anchor window before Firefox starts
    try:
        proc = await asyncio.create_subprocess_exec(
            "swaymsg",
            'for_window [title="^workspace-anchor"] move scratchpad',
        )
        await proc.wait()
        print("Registered sway rule for anchor window", file=sys.stderr)
    except Exception as e:
        print(f"Failed to register anchor sway rule: {e}", file=sys.stderr)

    initial_workspace = await get_current_workspace()
    if initial_workspace:
        manager.current_workspace = initial_workspace
        manager._write_state()
        print(f"Initial workspace: {initial_workspace}", file=sys.stderr)

    loop = asyncio.get_event_loop()

    def shutdown(sig: signal.Signals) -> None:
        print(f"Received {sig.name}, shutting down...", file=sys.stderr)
        for task in asyncio.all_tasks(loop):
            task.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, shutdown, sig)

    try:
        await asyncio.gather(
            subscribe_sway(),
            socket_server(),
        )
    except asyncio.CancelledError:
        print("Shutdown complete", file=sys.stderr)
    finally:
        if SOCKET_PATH.exists():
            SOCKET_PATH.unlink()


if __name__ == "__main__":
    asyncio.run(main())
