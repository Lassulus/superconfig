#!/usr/bin/env bash
set -euo pipefail

# Default recording duration in seconds
DURATION=${1:-5}

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
# Uses the base model by default, you can override with WHISPER_MODEL env var
whisper-cpp -m "${WHISPER_MODEL:-base.en}" -f "$TEMP_AUDIO" --no-timestamps --output-txt
