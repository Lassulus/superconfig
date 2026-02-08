#!/usr/bin/env bash
# Workspace Manager CLI
# Queries the workspace-manager-daemon for current workspace and directory info

set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SOCKET_PATH="$RUNTIME_DIR/workspace-manager/socket"

usage() {
    echo "Usage: workspace-manager <command>"
    echo ""
    echo "Commands:"
    echo "  dir        Print the directory for the current workspace"
    echo "  workspace  Print the current workspace name"
    echo "  status     Check if daemon is running and print status"
    echo "  help       Show this help message"
    exit 1
}

query_daemon() {
    local command="$1"
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo "Error: Daemon not running (socket not found)" >&2
        return 1
    fi

    # Send command and read response
    response=$(echo "$command" | socat - "UNIX-CONNECT:$SOCKET_PATH" 2>/dev/null)
    if [[ -z "$response" ]]; then
        echo "Error: No response from daemon" >&2
        return 1
    fi

    echo "$response"
}

cmd_dir() {
    response=$(query_daemon "dir") || exit 1
    echo "$response" | jq -r '.directory // empty'
}

cmd_workspace() {
    response=$(query_daemon "workspace") || exit 1
    echo "$response" | jq -r '.workspace // empty'
}

cmd_status() {
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo "Daemon is not running"
        exit 1
    fi

    response=$(query_daemon "status") || exit 1
    running=$(echo "$response" | jq -r '.running // false')

    if [[ "$running" == "true" ]]; then
        workspace=$(echo "$response" | jq -r '.workspace // "unknown"')
        directory=$(echo "$response" | jq -r '.directory // "unknown"')
        echo "Daemon is running"
        echo "  Workspace: $workspace"
        echo "  Directory: $directory"
    else
        echo "Daemon is not responding properly"
        exit 1
    fi
}

if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    dir)
        cmd_dir
        ;;
    workspace)
        cmd_workspace
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage
        ;;
esac
