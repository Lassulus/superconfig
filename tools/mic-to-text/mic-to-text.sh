#!/usr/bin/env bash
set -euo pipefail

# Default recording duration in seconds
DURATION=${1:-5}

# Model cache directory
MODEL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/whisper-models"
mkdir -p "$MODEL_DIR"

# Default model
MODEL_NAME="${WHISPER_MODEL:-base.en}"
MODEL_FILE="$MODEL_DIR/ggml-$MODEL_NAME.bin"

# Download model if not present
if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading $MODEL_NAME model (first run only)..." >&2
    MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL_NAME.bin"
    curl -L -o "$MODEL_FILE.tmp" "$MODEL_URL" && mv "$MODEL_FILE.tmp" "$MODEL_FILE"
fi

# Temporary file for audio recording
TEMP_AUDIO=$(mktemp /tmp/mic-to-text-XXXXXX.wav)
trap 'rm -f "$TEMP_AUDIO"' EXIT

echo "Recording for $DURATION seconds... (press Ctrl+C to stop early)" >&2

# Record audio from default microphone
# -r 16000: sample rate 16kHz (optimal for speech recognition)
# -c 1: mono channel
# -b 16: 16-bit audio
rec -q -r 16000 -c 1 -b 16 "$TEMP_AUDIO" trim 0 "$DURATION" || true

if [ ! -s "$TEMP_AUDIO" ]; then
    echo "Error: No audio recorded" >&2
    exit 1
fi

echo "Transcribing locally..." >&2

# Transcribe using whisper.cpp (runs locally, no API calls)
whisper-cli -m "$MODEL_FILE" -f "$TEMP_AUDIO" -np
