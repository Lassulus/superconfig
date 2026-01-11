#!/usr/bin/env bash
set -euo pipefail

list_sources() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: list audio devices via ffmpeg avfoundation
    echo "system: System Audio (via ScreenCaptureKit)"
    ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | \
      sed -n '/AVFoundation audio devices:/,/^[^[]/p' | \
      grep -E '^\[AVFoundation.*\[[0-9]+\]' | \
      sed 's/.*\[\([0-9]*\)\] \(.*\)/\1: \2/'
  else
    # Linux: list PulseAudio/PipeWire sources including monitors (for system audio)
    # Sources ending in .monitor capture the output of that sink (system audio)
    pactl list sources short | awk '{print $2}' | while read -r source; do
      if [[ "$source" == *.monitor ]]; then
        echo "$source (system audio)"
      else
        echo "$source"
      fi
    done
  fi
}

get_source_name() {
  # Strip the description suffix for actual recording
  local name="$1"
  echo "${name% (system audio)}"
}

record_source() {
  local source="$1"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ "$source" == "system" ]]; then
      # Use system-audio-dump for system audio (ScreenCaptureKit)
      # Output is raw PCM 24kHz 16-bit stereo, convert to WAV for compatibility
      system-audio-dump | ffmpeg -f s16le -ar 24000 -ac 2 -i - -f wav -acodec pcm_s16le - 2>/dev/null
    else
      # Use avfoundation for mic input, source is the device index
      ffmpeg -f avfoundation -i ":${source}" -f wav -acodec pcm_s16le - 2>/dev/null
    fi
  else
    # Linux: use pulse
    ffmpeg -f pulse -i "$source" -f wav -acodec pcm_s16le - 2>/dev/null
  fi
}

# Show help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo "Usage: record [SOURCE]"
  echo ""
  echo "Record audio from a source and output WAV to stdout."
  echo "If no source is provided, prompts interactively with gum."
  echo ""
  echo "Options:"
  echo "  -l, --list    List available audio sources"
  echo "  -h, --help    Show this help"
  echo ""
  echo "System audio:"
  echo "  Linux:  Select a .monitor source (captures sink output)"
  echo "  macOS:  Use 'system' source (requires Screen Recording permission)"
  echo ""
  echo "Examples:"
  echo "  record | mpv -"
  echo "  record system | mpv -                         # macOS system audio"
  echo "  record 0 | mpv -                              # macOS device index"
  echo "  record alsa_output.pci-xxx.monitor | mpv -    # Linux system audio"
  exit 0
fi

# List sources
if [[ "${1:-}" == "-l" ]] || [[ "${1:-}" == "--list" ]]; then
  list_sources
  exit 0
fi

# Get source from argument or prompt
if [[ -n "${1:-}" ]]; then
  SOURCE="$1"
else
  # Use gum to select a source
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SOURCE=$(list_sources | gum choose --header "Select audio source:" | cut -d: -f1)
  else
    SELECTION=$(list_sources | gum choose --header "Select audio source:")
    SOURCE=$(get_source_name "$SELECTION")
  fi
fi

if [[ -z "$SOURCE" ]]; then
  echo "Error: No source selected" >&2
  exit 1
fi

echo "Recording from: $SOURCE (Ctrl+C to stop)" >&2
record_source "$SOURCE"
