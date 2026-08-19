#!/usr/bin/env python3
"""Place new sway windows on the workspace of the process that spawned them.

Sway maps a new view onto the *currently focused* workspace. That is wrong
whenever the spawning process lives elsewhere: a build finishing in a terminal
on workspace "strom" pops its window onto whatever workspace happens to be
focused at that moment.

This daemon subscribes to sway's window::new events and resolves the workspace
of the spawning process by walking /proc PPid links until it hits a pid that
already owns a window. Terminals here exec tmux, which breaks the ppid chain at
the (session-global) tmux server, so the walk also hops tmux pane -> session ->
attached client pid and continues from there.

Windows whose ancestry cannot be resolved (systemd user services, dbus
activation, single-process multi-window apps like Firefox) keep sway's default
behaviour.
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections.abc import Iterator
from typing import Any

# Sway's hidden scratchpad workspace; views parked there must never be moved,
# and a view living there is not a placement hint for anything else.
SCRATCHPAD = "__i3_scratch"


def run(args: list[str]) -> str | None:
    """Run a command, returning its stdout, or None when it failed."""
    try:
        proc = subprocess.run(args, capture_output=True, text=True, check=False)
    except OSError as e:
        print(f"failed to run {args[0]}: {e}", file=sys.stderr)
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout


def swaymsg_json(*args: str) -> Any:
    """Query sway IPC, returning the parsed reply or None."""
    out = run(["swaymsg", "-r", "-t", *args])
    if out is None:
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError as e:
        print(f"failed to parse sway reply: {e}", file=sys.stderr)
        return None


def iter_views(
    node: dict[str, Any], workspace: str | None
) -> Iterator[tuple[str, int, int]]:
    """Yield (workspace name, container id, pid) for every view in the tree."""
    if node.get("type") == "workspace":
        workspace = node.get("name")
    pid = node.get("pid")
    if pid is not None and workspace is not None:
        yield workspace, int(node["id"]), int(pid)
    for key in ("nodes", "floating_nodes"):
        for child in node.get(key, []):
            yield from iter_views(child, workspace)


def parent_pid(pid: int) -> int | None:
    """Read PPid from /proc, or None if the process is gone."""
    try:
        with open(f"/proc/{pid}/status", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PPid:"):
                    return int(line.split()[1])
    except (OSError, ValueError):
        return None
    return None


def tmux_hops() -> dict[int, list[int]]:
    """Map each tmux pane's root pid to the pids of its session's clients.

    A process started inside a pane has that pane's root pid as an ancestor,
    but its ppid chain leads to the tmux server, not to the terminal window.
    The attached client processes are children of that terminal, so they are
    where the walk has to continue.
    """
    panes = run(["tmux", "list-panes", "-a", "-F", "#{pane_pid} #{session_id}"])
    clients = run(["tmux", "list-clients", "-F", "#{client_pid} #{session_id}"])
    if not panes or not clients:
        return {}
    session_clients: dict[str, list[int]] = {}
    for line in clients.splitlines():
        pid, _, session = line.partition(" ")
        try:
            session_clients.setdefault(session, []).append(int(pid))
        except ValueError:
            continue
    hops: dict[int, list[int]] = {}
    for line in panes.splitlines():
        pid, _, session = line.partition(" ")
        try:
            hops[int(pid)] = session_clients.get(session, [])
        except ValueError:
            continue
    return hops


def resolve_workspace(
    pid: int,
    pid_workspaces: dict[int, str],
    hops: dict[int, list[int]],
    visited: set[int],
) -> str | None:
    """Find the workspace of the nearest ancestor process that owns a window."""
    current: int | None = pid
    while current is not None and current > 1:
        if current in visited:
            return None
        visited.add(current)
        workspace = pid_workspaces.get(current)
        if workspace is not None:
            return workspace
        for client in hops.get(current, []):
            workspace = resolve_workspace(client, pid_workspaces, hops, visited)
            if workspace is not None:
                return workspace
        current = parent_pid(current)
    return None


def quote(name: str) -> str:
    """Quote a workspace name for a sway command."""
    escaped = name.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def handle_new_window(container_id: int, pid: int) -> None:
    """Move a freshly mapped view to the workspace of its spawning process."""
    tree = swaymsg_json("get_tree")
    if tree is None:
        return

    origin: str | None = None
    pid_workspaces: dict[int, str] = {}
    for workspace, view_id, view_pid in iter_views(tree, None):
        if view_id == container_id:
            origin = workspace
            continue
        # Views of the same process are no hint: a single-process multi-window
        # app (Firefox) would drag every new window to an unrelated workspace.
        if view_pid == pid or workspace.startswith(SCRATCHPAD):
            continue
        pid_workspaces.setdefault(view_pid, workspace)

    if origin is None or origin.startswith(SCRATCHPAD):
        # Window already closed again, or parked in the scratchpad by a
        # for_window rule (the workspace-manager Firefox anchor).
        return

    target = resolve_workspace(pid, pid_workspaces, tmux_hops(), set())
    if target is None or target == origin:
        return

    print(
        f"moving container {container_id} (pid {pid}): {origin} -> {target}",
        file=sys.stderr,
    )
    run(
        [
            "swaymsg",
            "--",
            f"[con_id={container_id}] move container to workspace {quote(target)}",
        ]
    )


def main() -> int:
    """Subscribe to sway window events and place new windows."""
    proc = subprocess.Popen(
        ["swaymsg", "-t", "subscribe", "-m", '["window"]'],
        stdout=subprocess.PIPE,
        text=True,
    )
    if proc.stdout is None:
        print("no stdout from swaymsg subscribe", file=sys.stderr)
        return 1

    for line in proc.stdout:
        try:
            event: dict[str, Any] = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"failed to parse sway event: {e}", file=sys.stderr)
            continue
        if event.get("change") != "new":
            continue
        container: dict[str, Any] = event.get("container") or {}
        pid = container.get("pid")
        container_id = container.get("id")
        if pid is None or container_id is None:
            continue
        handle_new_window(int(container_id), int(pid))

    return proc.wait()


if __name__ == "__main__":
    sys.exit(main())
