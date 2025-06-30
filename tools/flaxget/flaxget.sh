#!/usr/bin/env bash
set -euo pipefail

FLAX_URL="https://flax.lassul.us"
FLAX_USER="krebs"
STREAM_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--stream)
            STREAM_MODE=true
            shift
            ;;
        *)
            echo "Usage: $0 [-s|--stream]"
            echo "  -s, --stream  Stream files to mpv while downloading"
            exit 1
            ;;
    esac
done

# Try to get password from pass first
if command -v pass >/dev/null 2>&1 && pass git ls-files | grep -qE "^www/flax\.lassul\.us/pass\.(gpg|age)$"; then
    FLAX_PASS=$(pass show www/flax.lassul.us/pass)
else
    read -rsp "Password for $FLAX_USER@flax.lassul.us: " FLAX_PASS
    echo
fi

echo "Fetching file list..."
FILES=$(curl -s -u "$FLAX_USER:$FLAX_PASS" "$FLAX_URL/index")

if [[ -z "$FILES" ]]; then
    echo "Error: Failed to fetch file list or no files available"
    exit 1
fi

SELECTED=$(echo "$FILES" | fzf --multi --header="Select files to download (TAB to select multiple, ENTER to confirm)")

if [[ -z "$SELECTED" ]]; then
    echo "No files selected"
    exit 0
fi

if [[ "$STREAM_MODE" == "true" ]]; then
    # Check if mpv is available
    if ! command -v mpv >/dev/null 2>&1; then
        echo "Error: mpv is not installed. Stream mode requires mpv."
        exit 1
    fi
    
    # Stream mode: start aria2c in background to download all files
    # while playing them sequentially as they become available
    
    # Create a temporary file with URLs for aria2c
    TMPFILE=$(mktemp)
    trap 'rm -f "$TMPFILE"' EXIT
    
    # Store filenames in an array for playback
    declare -a FILES_ARRAY=()
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            # Extract just the filename from the path
            filename=$(basename "$file")
            echo "$FLAX_URL/$file" >> "$TMPFILE"
            FILES_ARRAY+=("$filename")
        fi
    done <<< "$SELECTED"
    
    echo "Starting background downloads..."
    # Start aria2c in background with progress bar
    aria2c --http-user="$FLAX_USER" --http-passwd="$FLAX_PASS" -i "$TMPFILE" --console-log-level=warn &
    ARIA_PID=$!
    
    # Play files as they download
    for file in "${FILES_ARRAY[@]}"; do
        echo "Waiting for $file to start downloading..."
        # Wait for file to exist and have some content
        while [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; do
            sleep 0.5
            # Check if aria2c is still running
            if ! kill -0 $ARIA_PID 2>/dev/null; then
                echo "Download process ended unexpectedly"
                break 2
            fi
        done
        
        # Give it a moment to buffer
        sleep 1
        
        echo "Playing: $file"
        mpv "$file"
    done
    
    # Wait for all downloads to complete
    wait $ARIA_PID
else
    # Normal mode: download all files with aria2c
    # Create a temporary file with URLs for aria2c
    TMPFILE=$(mktemp)
    trap 'rm -f "$TMPFILE"' EXIT

    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            echo "$FLAX_URL/$file" >> "$TMPFILE"
        fi
    done <<< "$SELECTED"

    echo "Downloading selected files..."
    aria2c --http-user="$FLAX_USER" --http-passwd="$FLAX_PASS" -i "$TMPFILE"
fi

echo "Download complete!"