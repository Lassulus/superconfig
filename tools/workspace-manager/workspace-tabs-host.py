#!/usr/bin/env python3
"""Native messaging host for the Workspace Tabs Firefox extension."""

from __future__ import annotations

import json
import os
import select
import socket
import struct
import subprocess
import sys
from pathlib import Path
from typing import Any

RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
SOCKET_PATH = RUNTIME_DIR / "workspace-manager" / "socket"


def read_message() -> dict[str, Any] | None:
    """Read a native messaging message from stdin."""
    raw = sys.stdin.buffer.read(4)
    if not raw or len(raw) < 4:
        return None
    length = struct.unpack("=I", raw)[0]
    result: dict[str, Any] = json.loads(sys.stdin.buffer.read(length))
    return result


def write_message(msg: dict[str, Any]) -> None:
    """Write a native messaging message to stdout."""
    data = json.dumps(msg).encode()
    sys.stdout.buffer.write(struct.pack("=I", len(data)) + data)
    sys.stdout.buffer.flush()


def run(cmd: list[str]) -> str:
    """Run a command and return stripped stdout, or empty string on failure."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=2)  # noqa: S603
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def get_firefox_windows() -> list[dict[str, str]]:
    """Get all Firefox windows and their workspaces from sway tree."""
    try:
        tree: dict[str, Any] = json.loads(run(["swaymsg", "-t", "get_tree", "-r"]))
    except (json.JSONDecodeError, ValueError):
        return []

    results: list[dict[str, str]] = []

    def traverse(node: dict[str, Any], workspace: str) -> None:
        node_type = node.get("type", "")
        if node_type == "workspace":
            workspace = node.get("name", workspace)
        app_id = node.get("app_id", "") or ""
        if "firefox" in app_id.lower() and node_type == "con":
            results.append(
                {
                    "workspace": workspace,
                    "windowTitle": node.get("name", ""),
                }
            )
        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            traverse(child, workspace)

    traverse(tree, "")
    return results


def handle(msg: dict[str, Any]) -> dict[str, Any]:
    """Handle a single message from the extension."""
    mid: int = msg.get("id", 0)
    cmd = msg.get("cmd", "")
    if cmd == "current_workspace":
        return {"id": mid, "workspace": run(["workspace-manager", "workspace"])}
    if cmd == "list_workspaces":
        try:
            ws: list[dict[str, Any]] = json.loads(
                run(["swaymsg", "-t", "get_workspaces", "-r"])
            )
            return {"id": mid, "workspaces": [w["name"] for w in ws]}
        except (json.JSONDecodeError, KeyError):
            return {"id": mid, "workspaces": []}
    if cmd == "goto_workspace":
        run(["goto-workspace", msg.get("name", "")])
        return {"id": mid, "ok": True}
    if cmd == "move_to_workspace":
        run(["swaymsg", "move", "container", "to", "workspace", msg.get("name", "")])
        return {"id": mid, "ok": True}
    if cmd == "map_windows":
        return {"id": mid, "windows": get_firefox_windows()}
    return {"id": mid, "error": f"Unknown: {cmd}"}


def connect_subscriber() -> socket.socket | None:
    """Connect to workspace-manager daemon as a subscriber."""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(str(SOCKET_PATH))
        sock.sendall(b"subscribe")
        sock.setblocking(False)
        return sock
    except OSError as e:
        print(f"Failed to subscribe to workspace-manager: {e}", file=sys.stderr)
        return None


def main() -> None:
    """Main loop: handle Firefox messages and workspace-manager events."""
    sub_sock = connect_subscriber()
    stdin_fd = sys.stdin.buffer.fileno()
    sub_buf = b""

    while True:
        read_fds = [stdin_fd]
        if sub_sock is not None:
            read_fds.append(sub_sock.fileno())

        try:
            readable, _, _ = select.select(read_fds, [], [], 10.0)
        except (ValueError, OSError):
            break

        if not readable and sub_sock is None:
            sub_sock = connect_subscriber()
            continue

        for fd in readable:
            if fd == stdin_fd:
                msg = read_message()
                if msg is None:
                    return
                write_message(handle(msg))
            elif sub_sock is not None and fd == sub_sock.fileno():
                try:
                    data = sub_sock.recv(4096)
                    if not data:
                        # Daemon disconnected, try to reconnect
                        sub_sock.close()
                        sub_sock = connect_subscriber()
                        continue
                    sub_buf += data
                    while b"\n" in sub_buf:
                        line, sub_buf = sub_buf.split(b"\n", 1)
                        event: dict[str, Any] = json.loads(line)
                        # Push workspace change event to Firefox
                        write_message(
                            {
                                "id": 0,
                                "event": "workspace_change",
                                "workspace": event.get("new", ""),
                            }
                        )
                except (OSError, json.JSONDecodeError) as e:
                    print(f"Subscriber error: {e}", file=sys.stderr)
                    if sub_sock is not None:
                        sub_sock.close()
                    sub_sock = None


if __name__ == "__main__":
    main()
