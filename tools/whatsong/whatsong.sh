#!/usr/bin/env bash
set -euo pipefail

# Recording duration in seconds (default: 5)
DURATION=${1:-5}

# Temporary file for audio
TEMP_AUDIO=$(mktemp /tmp/whatsong-XXXXXX.wav)
trap 'rm -f "$TEMP_AUDIO"' EXIT

echo "Listening for $DURATION seconds..." >&2

# Record audio from default microphone
# songrec needs specific format: 16kHz mono
rec -q -r 16000 -c 1 -b 16 "$TEMP_AUDIO" trim 0 "$DURATION" 2>/dev/null || true

if [ ! -s "$TEMP_AUDIO" ]; then
    echo "Error: No audio recorded" >&2
    exit 1
fi

echo "Identifying song..." >&2

# Run songrec and get JSON output
RESULT=$(songrec recognize --json "$TEMP_AUDIO" 2>/dev/null)

if [ -z "$RESULT" ] || [ "$RESULT" = "null" ]; then
    echo "Could not identify song" >&2
    exit 1
fi

# Extract artist and title
ARTIST=$(echo "$RESULT" | jq -r '.track.subtitle // empty')
TITLE=$(echo "$RESULT" | jq -r '.track.title // empty')

if [ -z "$TITLE" ]; then
    echo "Could not identify song" >&2
    exit 1
fi

echo "Found: $ARTIST - $TITLE" >&2

# Search YouTube and get first result
SEARCH_QUERY="$ARTIST $TITLE"
echo "Searching YouTube..." >&2

yt-dlp --dump-json "ytsearch1:$SEARCH_QUERY" 2>/dev/null | jq -r '.webpage_url'
