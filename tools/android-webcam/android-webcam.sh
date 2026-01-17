SHADER_TEMPLATE="@shaderPath@"
ASCII_MODE=false
ASCII_SCALE=6

while [[ $# -gt 0 ]]; do
  case $1 in
    --ascii)
      ASCII_MODE=true
      shift
      # Check if next arg is a number (the scale)
      if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
        ASCII_SCALE=$1
        shift
      fi
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: android-webcam [--ascii [SIZE]]" >&2
      echo "  SIZE: character size 1-20 (default: 6)" >&2
      exit 1
      ;;
  esac
done

if $ASCII_MODE; then
  # ASCII mode needs both devices
  if [[ ! -e /dev/video0 ]] || [[ ! -e /dev/video1 ]]; then
    echo "Error: /dev/video0 and /dev/video1 must exist for ASCII mode" >&2
    echo "v4l2loopback should be configured with devices=2" >&2
    exit 1
  fi
  # Generate shader with scale value
  SHADER_PATH=$(mktemp --suffix=.hook)
  sed "s/@SCALE@/${ASCII_SCALE}/" "${SHADER_TEMPLATE}" > "${SHADER_PATH}"
else
  if [[ ! -e /dev/video0 ]]; then
    echo "Error: /dev/video0 must exist" >&2
    exit 1
  fi
fi

cleanup() {
  echo "Stopping..."
  kill "${SCRCPY_PID}" 2>/dev/null || true
  [[ -n "${FFMPEG_PID:-}" ]] && kill "${FFMPEG_PID}" 2>/dev/null || true
  [[ -n "${SHADER_PATH:-}" && -f "${SHADER_PATH}" ]] && rm -f "${SHADER_PATH}"
}
trap cleanup EXIT

# Start scrcpy to stream phone camera to /dev/video0
echo "Starting phone camera stream..."
scrcpy \
  --video-source=camera \
  --camera-facing=back \
  --no-audio \
  --v4l2-sink=/dev/video0 \
  --video-encoder=c2.exynos.h264.encoder \
  --camera-size=1920x1080 &
SCRCPY_PID=$!

if $ASCII_MODE; then
  sleep 2

  # Start ffmpeg with ASCII shader to /dev/video1
  echo "Starting ASCII filter pipeline (scale=${ASCII_SCALE})..."
  ffmpeg \
    -f v4l2 -i /dev/video0 \
    -vf "libplacebo=custom_shader_path=${SHADER_PATH}" \
    -f v4l2 -pix_fmt yuv420p /dev/video1 &
  FFMPEG_PID=$!

  echo ""
  echo "Android ASCII webcam running!"
  echo "  Raw camera: /dev/video0 (Phone Camera)"
  echo "  ASCII output: /dev/video1 (ASCII Webcam)"
  echo "  Character size: ${ASCII_SCALE}"
else
  echo ""
  echo "Android webcam running!"
  echo "  Camera: /dev/video0 (Phone Camera)"
fi

echo ""
echo "Press Ctrl+C to stop"

wait
