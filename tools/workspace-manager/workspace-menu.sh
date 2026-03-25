#!/usr/bin/env bash
# Workspace Menu for workspace management

set -euo pipefail

WORKSPACES_DIR="${HOME}/workspaces"
mkdir -p "$WORKSPACES_DIR"

get_current_workspace() {
  swaymsg -r -t get_workspaces | jq -r '.[] | select(.focused == true).name'
}

# Restore browser tabs from saved config (opens a new Firefox window with saved tabs)
action_restore() {
  local ws_name
  ws_name=$(get_current_workspace)
  local config_file="${WORKSPACES_DIR}/${ws_name}.json"

  if [ ! -f "$config_file" ]; then
    notify-send "Workspace Manager" "No config found for workspace '${ws_name}'"
    return 1
  fi

  local tab_count
  tab_count=$(jq '.tabs // [] | length' "$config_file" 2>/dev/null)

  if [ "$tab_count" -eq 0 ]; then
    notify-send "Workspace Manager" "No saved tabs for workspace '${ws_name}'"
    return 0
  fi

  # Open each saved tab URL in Firefox
  local urls
  urls=$(jq -r '.tabs // [] | .[].url' "$config_file" 2>/dev/null)

  local first=true
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    if [ "$first" = true ]; then
      firefox --new-window "$url" &
      first=false
      sleep 1
    else
      firefox "$url" &
    fi
  done <<< "$urls"

  notify-send "Workspace Manager" "Restored ${tab_count} tabs for workspace '${ws_name}'"
}

# Close workspace: kill all windows
action_close() {
  local ws_name
  ws_name=$(get_current_workspace)

  local confirm
  confirm=$(printf "Yes\nNo" | menu -p "Close workspace '${ws_name}'? (kills all windows)")
  if [ "$confirm" != "Yes" ]; then
    return 0
  fi

  local pids
  pids=$(swaymsg -r -t get_tree | jq --arg ws "$ws_name" '
    [.nodes[].nodes[] |
    select(.name == $ws) |
    .. |
    select(.type? == "con" and .pid? != null) |
    .pid] | unique | .[]
  ')

  for pid in $pids; do
    kill "$pid" 2>/dev/null || true
  done

  notify-send "Workspace Manager" "Closed workspace '${ws_name}'"
}

# Delete a workspace configuration
action_delete() {
  local configs
  configs=$(find "$WORKSPACES_DIR" -name '*.json' -printf '%f\n' | sed 's/\.json$//' | sort)

  if [ -z "$configs" ]; then
    notify-send "Workspace Manager" "No workspace configs found"
    return 0
  fi

  local selected
  selected=$(echo "$configs" | menu -p "Delete workspace config")
  if [ -z "$selected" ]; then
    return 0
  fi

  local confirm
  confirm=$(printf "Yes\nNo" | menu -p "Delete config for '${selected}'?")
  if [ "$confirm" = "Yes" ]; then
    rm "${WORKSPACES_DIR}/${selected}.json"
    notify-send "Workspace Manager" "Deleted config for '${selected}'"
  fi
}

# Edit a workspace configuration
action_edit() {
  local ws_name
  ws_name=$(get_current_workspace)

  local configs
  configs=$(find "$WORKSPACES_DIR" -name '*.json' -printf '%f\n' | sed 's/\.json$//' | sort)

  if ! echo "$configs" | grep -qx "$ws_name"; then
    configs="${ws_name}"$'\n'"${configs}"
  fi

  local selected
  selected=$(echo "$configs" | menu -p "Edit workspace config")
  if [ -z "$selected" ]; then
    return 0
  fi

  local config_file="${WORKSPACES_DIR}/${selected}.json"

  if [ ! -f "$config_file" ]; then
    echo '{}' > "$config_file"
  fi

  swaymsg exec "${TERMINAL:-kitty} ${EDITOR:-vim} $config_file"
}

# Main menu
main() {
  local ws_name
  ws_name=$(get_current_workspace)

  local choice
  choice=$(printf "Restore tabs\nClose workspace\nEdit config\nDelete config" | \
    menu -p "Workspace: ${ws_name}")

  case "$choice" in
    "Restore tabs")
      action_restore
      ;;
    "Close workspace")
      action_close
      ;;
    "Edit config")
      action_edit
      ;;
    "Delete config")
      action_delete
      ;;
  esac
}

main
