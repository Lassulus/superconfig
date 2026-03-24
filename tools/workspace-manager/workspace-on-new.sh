#!/usr/bin/env bash
# Called by workspace-manager-daemon when entering a workspace for the first time.
# Shows a rofi menu to restore saved session or start fresh.
# Arguments: $1 = workspace name

set -euo pipefail

WORKSPACES_DIR="${HOME}/workspaces"
WS_NAME="$1"
CONFIG_FILE="${WORKSPACES_DIR}/${WS_NAME}.json"

# No config file — nothing to restore, proceed silently
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

config=$(cat "$CONFIG_FILE")

directory=$(echo "$config" | jq -r '.directory // empty')
on_create=$(echo "$config" | jq -r '.on_create // []')
layout=$(echo "$config" | jq -r '.layout // []')

on_create_count=$(echo "$on_create" | jq 'length')
layout_count=$(echo "$layout" | jq 'length')

# Nothing meaningful in config — proceed silently
if [ "$on_create_count" -eq 0 ] && [ "$layout_count" -eq 0 ] && [ -z "$directory" ]; then
  exit 0
fi

# Build preview of what can be restored
preview=""
if [ -n "$directory" ]; then
  preview="Directory: ${directory}\n"
fi
if [ "$on_create_count" -gt 0 ]; then
  cmds=$(echo "$on_create" | jq -r '.[]' | sed 's/^/  /')
  preview="${preview}Commands (${on_create_count}):\n${cmds}\n"
fi
if [ "$layout_count" -gt 0 ]; then
  apps=$(echo "$layout" | jq -r '.[].app_id // .[].class // "unknown"' | sort -u | sed 's/^/  /')
  preview="${preview}Saved windows (${layout_count}):\n${apps}\n"
fi

choice=$(echo -e "Restore session\nNew session" | \
  rofi -dmenu -p "Workspace: ${WS_NAME}" -mesg "$(echo -e "$preview")")

case "$choice" in
  "Restore session")
    # Exit 0 — daemon will run on_create, Firefox will restore tabs
    exit 0
    ;;
  "New session"|"")
    # Exit 1 — daemon will skip on_create, Firefox won't restore tabs
    exit 1
    ;;
esac
