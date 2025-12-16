#!/usr/bin/env bash
set -euo pipefail

# TUI Stream Server - Desktop streaming server
# Captures the screen and streams it over TCP

PORT="${TUI_STREAM_PORT:-9999}"
FRAMERATE="${TUI_STREAM_FPS:-30}"
QUALITY="${TUI_STREAM_QUALITY:-23}"  # CRF value, lower = better quality
PRESET="${TUI_STREAM_PRESET:-ultrafast}"

usage() {
    cat <<EOF
Usage: tui-stream-server [OPTIONS]

Options:
    -p, --port PORT       Port to listen on (default: 9999, env: TUI_STREAM_PORT)
    -f, --fps FPS         Framerate (default: 30, env: TUI_STREAM_FPS)
    -q, --quality CRF     Quality (0-51, lower=better, default: 23, env: TUI_STREAM_QUALITY)
    --preset PRESET       Encoding preset (default: ultrafast, env: TUI_STREAM_PRESET)
    -h, --help            Show this help

Environment variables:
    TUI_STREAM_PORT       Default port
    TUI_STREAM_FPS        Default framerate
    TUI_STREAM_QUALITY    Default quality (CRF)
    TUI_STREAM_PRESET     Default preset

Example:
    tui-stream-server -p 8080 -f 60
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -f|--fps)
            FRAMERATE="$2"
            shift 2
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        --preset)
            PRESET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

echo "Starting TUI Stream Server on port $PORT..."
echo "Settings: ${FRAMERATE}fps, quality=$QUALITY, preset=$PRESET"
echo "Clients can connect with: tui-stream-client <your-ip>:$PORT"
echo ""

# Detect display server and start capture
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "Detected Wayland display, using wf-recorder + ffmpeg..."

    # Use wf-recorder for Wayland capture, pipe to ffmpeg for streaming
    wf-recorder \
        --muxer=rawvideo \
        --codec=rawvideo \
        --file=- \
        --pixel-format=bgr0 \
        --framerate="$FRAMERATE" \
        2>/dev/null | \
    ffmpeg \
        -f rawvideo \
        -pixel_format bgr0 \
        -video_size "$(wlr-randr 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo '1920x1080')" \
        -framerate "$FRAMERATE" \
        -i - \
        -c:v libx264 \
        -preset "$PRESET" \
        -tune zerolatency \
        -crf "$QUALITY" \
        -pix_fmt yuv420p \
        -f mpegts \
        "tcp://0.0.0.0:$PORT?listen=1"

elif [[ -n "${DISPLAY:-}" ]]; then
    echo "Detected X11 display, using ffmpeg x11grab..."

    # Get screen resolution
    RESOLUTION=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' || echo "1920x1080")

    ffmpeg \
        -f x11grab \
        -framerate "$FRAMERATE" \
        -video_size "$RESOLUTION" \
        -i "$DISPLAY" \
        -c:v libx264 \
        -preset "$PRESET" \
        -tune zerolatency \
        -crf "$QUALITY" \
        -pix_fmt yuv420p \
        -f mpegts \
        "tcp://0.0.0.0:$PORT?listen=1"
else
    echo "Error: No display detected (neither WAYLAND_DISPLAY nor DISPLAY is set)" >&2
    exit 1
fi
