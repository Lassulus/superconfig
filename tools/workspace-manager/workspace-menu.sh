#!/usr/bin/env bash
# Workspace Menu - rofi-based menu for workspace management
# Provides: save layout, restore workspace, delete config, edit config

set -euo pipefail

WORKSPACES_DIR="${HOME}/workspaces"
mkdir -p "$WORKSPACES_DIR"

# Get current workspace name from sway
get_current_workspace() {
  swaymsg -r -t get_workspaces | jq -r '.[] | select(.focused == true).name'
}

# Get the sway tree for the current workspace (app_id for each window)
capture_layout() {
  local ws_name="$1"
  swaymsg -r -t get_tree | jq --arg ws "$ws_name" '
    [.nodes[].nodes[] |
    select(.name == $ws) |
    .. |
    select(.type? == "con" and .app_id? != null) |
    {app_id: .app_id}]
  '
}

# Save current workspace layout
action_save() {
  local ws_name
  ws_name=$(get_current_workspace)
  local config_file="${WORKSPACES_DIR}/${ws_name}.json"

  # Capture current windows
  local layout
  layout=$(capture_layout "$ws_name")

  # Load existing config or start fresh
  local existing="{}"
  if [ -f "$config_file" ]; then
    existing=$(cat "$config_file")
  fi

  # Merge layout into existing config
  echo "$existing" | jq --argjson layout "$layout" '. + {layout: $layout}' > "$config_file"

  notify-send "Workspace Manager" "Saved layout for workspace '${ws_name}' ($(echo "$layout" | jq 'length') windows)"
}

# Launch an app by its app_id in the given working directory
launch_app() {
  local app_id="$1"
  local work_dir="$2"

  case "$app_id" in
    kitty|foot|alacritty|wezterm)
      # Terminal emulators: open in workspace directory
      cd "$work_dir" && "$app_id" &
      ;;
    *)
      # Skip everything else (browsers handled by Firefox extension)
      ;;
  esac
}

# Restore workspace to its original state (kill windows + re-run on_create + reopen layout)
action_restore() {
  local ws_name
  ws_name=$(get_current_workspace)
  local config_file="${WORKSPACES_DIR}/${ws_name}.json"

  if [ ! -f "$config_file" ]; then
    notify-send "Workspace Manager" "No config found for workspace '${ws_name}'"
    return 1
  fi

  # Confirm via rofi
  local confirm
  confirm=$(printf "Yes\nNo" | rofi -dmenu -p "Restore workspace '${ws_name}'? (kills all windows)")
  if [ "$confirm" != "Yes" ]; then
    return 0
  fi

  # Kill all windows on current workspace
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

  # Wait a moment for windows to close
  sleep 1

  local directory
  directory=$(jq -r '.directory // "~"' "$config_file" 2>/dev/null)
  directory="${directory/#\~/$HOME}"

  # Run on_create commands in tmux sessions
  local on_create
  on_create=$(jq -r '.on_create // [] | .[]' "$config_file" 2>/dev/null)

  if [ -n "$on_create" ]; then
    local i=1
    while IFS= read -r cmd; do
      local session_name="${ws_name}-start${i}"
      # Kill existing tmux session if present
      tmux kill-session -t "$session_name" 2>/dev/null || true
      # Create new tmux session
      tmux new-session -d -s "$session_name" -c "$directory" "$cmd"
      # Open terminal attached to it
      kitty -T "$session_name" tmux attach -t "$session_name" &
      i=$((i + 1))
    done <<< "$on_create"
  fi

  # Reopen windows from saved layout
  local layout_count
  layout_count=$(jq '.layout // [] | length' "$config_file" 2>/dev/null)

  if [ "$layout_count" -gt 0 ]; then
    local app_ids
    app_ids=$(jq -r '.layout // [] | .[].app_id // empty' "$config_file" 2>/dev/null)

    while IFS= read -r app_id; do
      [ -n "$app_id" ] && launch_app "$app_id" "$directory"
    done <<< "$app_ids"
  fi

  notify-send "Workspace Manager" "Restored workspace '${ws_name}'"
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
  selected=$(echo "$configs" | rofi -dmenu -p "Delete workspace config")
  if [ -z "$selected" ]; then
    return 0
  fi

  local confirm
  confirm=$(printf "Yes\nNo" | rofi -dmenu -p "Delete config for '${selected}'?")
  if [ "$confirm" = "Yes" ]; then
    rm "${WORKSPACES_DIR}/${selected}.json"
    notify-send "Workspace Manager" "Deleted config for '${selected}'"
  fi
}

# Edit a workspace configuration
action_edit() {
  local ws_name
  ws_name=$(get_current_workspace)

  # List existing configs + option for current workspace
  local configs
  configs=$(find "$WORKSPACES_DIR" -name '*.json' -printf '%f\n' | sed 's/\.json$//' | sort)

  # Prepend current workspace if not already in list
  if ! echo "$configs" | grep -qx "$ws_name"; then
    configs="${ws_name}"$'\n'"${configs}"
  fi

  local selected
  selected=$(echo "$configs" | rofi -dmenu -p "Edit workspace config")
  if [ -z "$selected" ]; then
    return 0
  fi

  local config_file="${WORKSPACES_DIR}/${selected}.json"

  # Create default config if it doesn't exist
  if [ ! -f "$config_file" ]; then
    echo '{}' > "$config_file"
  fi

  # Open in terminal with $EDITOR
  kitty "${EDITOR:-vim}" "$config_file" &
}

# Close workspace: kill all windows and remove the workspace
action_close() {
  local ws_name
  ws_name=$(get_current_workspace)

  local confirm
  confirm=$(printf "Yes\nNo" | rofi -dmenu -p "Close workspace '${ws_name}'? (kills all windows)")
  if [ "$confirm" != "Yes" ]; then
    return 0
  fi

  # Kill all windows on current workspace
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

  # Kill associated tmux sessions
  local i=1
  while tmux has-session -t "${ws_name}-start${i}" 2>/dev/null; do
    tmux kill-session -t "${ws_name}-start${i}" 2>/dev/null || true
    i=$((i + 1))
  done

  notify-send "Workspace Manager" "Closed workspace '${ws_name}'"
}

# Main menu
main() {
  local ws_name
  ws_name=$(get_current_workspace)

  local choice
  choice=$(printf "Save layout\nRestore workspace\nClose workspace\nEdit config\nDelete config" | \
    rofi -dmenu -p "Workspace: ${ws_name}")

  case "$choice" in
    "Save layout")
      action_save
      ;;
    "Restore workspace")
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
