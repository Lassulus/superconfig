#!/usr/bin/env bash
set -euo pipefail

# TUI Stream Client - Connect to a streaming server
# Receives video stream and plays it with a configurable player

PLAYER="${TUI_STREAM_PLAYER:-mpv}"
PLAYER_ARGS="${TUI_STREAM_PLAYER_ARGS:---profile=low-latency --untimed --no-cache}"

usage() {
    cat <<EOF
Usage: tui-stream-client [OPTIONS] <host:port>

Connect to a TUI stream server and play the video stream.

Arguments:
    <host:port>           Server address (e.g., 192.168.1.100:9999)

Options:
    -p, --player PLAYER   Video player to use (default: mpv, env: TUI_STREAM_PLAYER)
    --player-args ARGS    Arguments for the player (env: TUI_STREAM_PLAYER_ARGS)
                          Default: --profile=low-latency --untimed --no-cache
    -h, --help            Show this help

Environment variables:
    TUI_STREAM_PLAYER       Default video player
    TUI_STREAM_PLAYER_ARGS  Default player arguments

Examples:
    tui-stream-client 192.168.1.100:9999
    tui-stream-client -p vlc server.local:8080
    TUI_STREAM_PLAYER=ffplay tui-stream-client localhost:9999
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--player)
            PLAYER="$2"
            shift 2
            ;;
        --player-args)
            PLAYER_ARGS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    echo "Error: Missing server address" >&2
    echo ""
    usage
fi

SERVER="$1"

# Validate server address format
if [[ ! "$SERVER" =~ ^[a-zA-Z0-9._-]+:[0-9]+$ ]]; then
    echo "Error: Invalid server address format. Use host:port (e.g., 192.168.1.100:9999)" >&2
    exit 1
fi

echo "Connecting to $SERVER..."
echo "Using player: $PLAYER $PLAYER_ARGS"
echo "Press Ctrl+C to stop"
echo ""

# Build the stream URL
STREAM_URL="tcp://$SERVER"

# Launch the player with the stream
# shellcheck disable=SC2086
exec "$PLAYER" $PLAYER_ARGS "$STREAM_URL"
