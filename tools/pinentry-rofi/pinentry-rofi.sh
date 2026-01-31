#!/usr/bin/env bash
# pinentry-rofi: A rofi-based pinentry for SSH TPM authentication
# Reads SSH_CLIENT_PID to extract SSH command context
set -efu

# Extract SSH args from client PID
# Groups flags with their arguments on the same line
get_ssh_args() {
  local pid="${SSH_CLIENT_PID:-}"
  [[ -z "$pid" ]] && return 1
  [[ ! -r "/proc/$pid/cmdline" ]] && return 1

  # Read command line (null-separated) into array
  local -a args=()
  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < "/proc/$pid/cmdline"

  # Check first arg is ssh
  [[ "${args[0]}" == "ssh" || "${args[0]}" == */ssh ]] || return 1

  # Output args, keeping flags and their values on the same line
  local i=1
  local line=""
  while [[ $i -lt ${#args[@]} ]]; do
    local arg="${args[$i]}"
    if [[ "$arg" == -* ]]; then
      # Print previous line if exists
      [[ -n "$line" ]] && echo "$line"
      line="$arg"
    else
      # Append to current line
      if [[ -n "$line" ]]; then
        line="$line $arg"
      else
        line="$arg"
      fi
    fi
    ((i++))
  done
  # Print last line
  [[ -n "$line" ]] && echo "$line"
}

# Get SSH args
ssh_args=""
if ssh_args=$(get_ssh_args 2>/dev/null); then
  : # got args
fi

# Build the rofi message
mesg_args=()
if [[ -n "$ssh_args" ]]; then
  mesg="<b>SSH:</b>
$ssh_args"
  mesg_args=(-mesg "$mesg")
fi

# Determine theme
theme_file="/var/theme/config/rofi-theme"
theme_args=()
if [[ -r "$theme_file" ]]; then
  theme=$(cat "$theme_file")
  theme_args=(-theme "$theme")
fi

# Use rofi in password mode
result=$(rofi -dmenu \
  -password \
  -p "PIN" \
  -lines 0 \
  -no-fixed-num-lines \
  "${mesg_args[@]}" \
  "${theme_args[@]}" \
  < /dev/null 2>/dev/null) || exit 1

echo "$result"
