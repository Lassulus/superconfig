#!/usr/bin/env bash
# HedgeDoc pad management script
# Usage:
#   pad.sh read <pad-id>           - Read pad content
#   pad.sh create [file|-]         - Create new pad, returns URL
#   pad.sh edit <pad-id> [file|-]  - Replace pad content in-place
#   pad.sh info <pad-id>           - Get pad metadata

set -euo pipefail

HEDGEDOC_URL="https://pad.lassul.us"
SKILL_DIR="${SKILL_DIR:-$(cd "$(dirname "$0")" && pwd)}"

cmd="${1:-help}"
shift || true

case "$cmd" in
  read)
    PADID="${1:?Usage: pad.sh read <pad-id>}"
    curl -sf "${HEDGEDOC_URL}/${PADID}/download"
    ;;

  create)
    if [ -n "${1:-}" ] && [ -f "$1" ]; then
      CONTENT=$(cat "$1")
    elif [ -n "${1:-}" ] && [ "$1" = "-" ]; then
      CONTENT=$(cat)
    else
      CONTENT=$(cat)
    fi
    PAD_URL=$(curl -s -o /dev/null -w "%{redirect_url}" \
      -X POST "${HEDGEDOC_URL}/new" \
      -H "Content-Type: text/markdown" \
      -d "$CONTENT")
    echo "$PAD_URL"
    ;;

  edit)
    PADID="${1:?Usage: pad.sh edit <pad-id> [file|-]}"
    shift
    exec "$SKILL_DIR/pad-edit.py" "$PADID" "$@"
    ;;

  info)
    PADID="${1:?Usage: pad.sh info <pad-id>}"
    curl -sf "${HEDGEDOC_URL}/${PADID}/info"
    ;;

  help|*)
    echo "Usage: pad.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  read <pad-id>             Read pad content (markdown)"
    echo "  create [file|-]           Create new pad, returns URL"
    echo "  edit <pad-id> [file|-]    Replace pad content in-place via websocket"
    echo "  info <pad-id>             Get pad metadata (JSON)"
    ;;
esac
