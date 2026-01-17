#!/usr/bin/env bash
DEVICE="/dev/video0"
LOOP=true

usage() {
  echo "Usage: video-webcam [OPTIONS] <video-file>"
  echo ""
  echo "Stream a video file to a virtual webcam device."
  echo ""
  echo "Options:"
  echo "  -d, --device DEVICE   v4l2 device to use (default: /dev/video0)"
  echo "  --no-loop             Don't loop the video"
  echo "  -h, --help            Show this help"
  echo ""
  echo "Examples:"
  echo "  video-webcam funny.gif"
  echo "  video-webcam -d /dev/video1 background.mp4"
  echo "  video-webcam --no-loop intro.webm"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--device)
      DEVICE="$2"
      shift 2
      ;;
    --no-loop)
      LOOP=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      VIDEO_FILE="$1"
      shift
      ;;
  esac
done

if [[ -z "${VIDEO_FILE:-}" ]]; then
  echo "Error: No video file specified" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$VIDEO_FILE" ]]; then
  echo "Error: File not found: $VIDEO_FILE" >&2
  exit 1
fi

if [[ ! -e "$DEVICE" ]]; then
  echo "Error: Device $DEVICE does not exist" >&2
  echo "Make sure v4l2loopback kernel module is loaded" >&2
  exit 1
fi

echo "Streaming '$VIDEO_FILE' to $DEVICE"
if $LOOP; then
  echo "Looping enabled (Ctrl+C to stop)"
fi
echo ""

LOOP_ARG=""
if $LOOP; then
  LOOP_ARG="-stream_loop -1"
fi

# shellcheck disable=SC2086
exec ffmpeg \
  $LOOP_ARG \
  -re \
  -i "$VIDEO_FILE" \
  -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
  -f v4l2 \
  "$DEVICE"
