#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    message="Attention requested."
else
    message="$*"
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "say" "$message" || true
fi

flite -t "$message"
