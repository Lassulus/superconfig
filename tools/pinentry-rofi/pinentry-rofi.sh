#!/usr/bin/env bash
# pinentry-rofi: A rofi-based pinentry for SSH TPM authentication
# Reads SSH_CLIENT_PID to extract SSH command context
# Caches PIN in kernel keyring for 5 minutes (sliding window)
set -efu

CACHE_KEY="pinentry-rofi-pin"
CACHE_TIMEOUT=300  # 5 minutes

# Get cached PIN from kernel keyring
get_cached_pin() {
  local key_id
  key_id=$(keyctl search @u user "$CACHE_KEY" 2>/dev/null) || return 1
  keyctl pipe "$key_id" 2>/dev/null
}

# Store PIN in kernel keyring with timeout
cache_pin() {
  local pin="$1"
  # Remove old key if exists
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
  # Add new key with timeout
  local key_id
  key_id=$(keyctl add user "$CACHE_KEY" "$pin" @u)
  keyctl timeout "$key_id" "$CACHE_TIMEOUT"
}

# Extend cache timeout (sliding window)
extend_cache() {
  local key_id
  key_id=$(keyctl search @u user "$CACHE_KEY" 2>/dev/null) || return 1
  keyctl timeout "$key_id" "$CACHE_TIMEOUT"
}

# Clear cached PIN
clear_cache() {
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
}

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

# Escape string for pango markup
escape_pango() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# Get SSH args
ssh_args=""
if ssh_args=$(get_ssh_args 2>/dev/null | escape_pango); then
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

# Check for cached PIN
cached_pin=""
if cached_pin=$(get_cached_pin 2>/dev/null) && [[ -n "$cached_pin" ]]; then
  # Show menu with cache options
  choice=$(printf "OK\nCancel\nClear cache" | rofi -dmenu \
    -i \
    -no-custom \
    -no-fixed-num-lines \
    "${mesg_args[@]}" \
    "${theme_args[@]}" \
    2>/dev/null) || exit 1

  case "$choice" in
    "OK")
      extend_cache
      echo "$cached_pin"
      exit 0
      ;;
    "Cancel")
      exit 1
      ;;
    "Clear cache")
      clear_cache
      exit 1
      ;;
  esac
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

# Cache the PIN
cache_pin "$result"

echo "$result"
