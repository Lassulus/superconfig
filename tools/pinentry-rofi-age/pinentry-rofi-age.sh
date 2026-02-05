#!/usr/bin/env bash
# pinentry-rofi-age: A rofi-based pinentry for age-plugin-tpm
# Shows the file being decrypted and caches PIN in kernel keyring
set -efu

CACHE_KEY="pinentry-rofi-age-pin"
CACHE_TIMEOUT=300  # 5 minutes

# Get cached PIN from kernel keyring
get_cached_pin() {
  local key_id
  key_id=$(keyctl search @s user "$CACHE_KEY" 2>/dev/null) || return 1
  keyctl pipe "$key_id" 2>/dev/null
}

# Store PIN in kernel keyring with timeout
cache_pin() {
  local pin="$1"
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
  local key_id
  key_id=$(printf '%s' "$pin" | keyctl padd user "$CACHE_KEY" @s) || return 0
  keyctl timeout "$key_id" "$CACHE_TIMEOUT" || true
}

# Extend cache timeout (sliding window)
extend_cache() {
  local key_id
  key_id=$(keyctl search @s user "$CACHE_KEY" 2>/dev/null) || return 0
  keyctl timeout "$key_id" "$CACHE_TIMEOUT" || true
}

# Clear cached PIN
clear_cache() {
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
}

# Escape string for pango markup
escape_pango() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# Determine target for display
raw_target="${1:-<stdin>}"
target=$(printf "%s" "$raw_target" | escape_pango)

# Build the rofi message
mesg="<b>Decrypt:</b>
$target"
mesg_args=(-mesg "$mesg")

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
      # Fall through to password prompt below
      ;;
  esac
fi

# Use rofi in password mode
result=$(rofi -dmenu \
  -password \
  -p "TPM PIN" \
  -lines 0 \
  -no-fixed-num-lines \
  "${mesg_args[@]}" \
  "${theme_args[@]}" \
  < /dev/null 2>/dev/null) || exit 1

if [[ -z "$result" ]]; then
  exit 1
fi

cache_pin "$result"

echo "$result"
