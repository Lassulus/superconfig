#!/usr/bin/env bash
# pinentry-rofi: A rofi-based pinentry
#
# Dual-mode:
#   - SSH_ASKPASS mode: invoked with a prompt string as $1 (e.g. by
#     ssh-tpm-agent via SSH_ASKPASS). Prints the PIN on stdout.
#   - Assuan/pinentry mode: invoked with no args or only "--" options
#     (e.g. by rbw, gpg-agent). Speaks the Assuan protocol on stdin/stdout.
#
# Caches PIN in kernel keyring for 5 minutes (sliding window).
set -efu

CACHE_KEY="pinentry-rofi-pin"
CACHE_TIMEOUT=300  # 5 minutes

# ---------- cache helpers ----------

get_cached_pin() {
  local key_id
  key_id=$(keyctl search @u user "$CACHE_KEY" 2>/dev/null) || return 1
  keyctl pipe "$key_id" 2>/dev/null
}

cache_pin() {
  local pin="$1"
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
  local key_id
  key_id=$(printf '%s' "$pin" | keyctl padd user "$CACHE_KEY" @u) || return 0
  keyctl timeout "$key_id" "$CACHE_TIMEOUT" || true
}

extend_cache() {
  local key_id
  key_id=$(keyctl search @u user "$CACHE_KEY" 2>/dev/null) || return 0
  keyctl timeout "$key_id" "$CACHE_TIMEOUT" || true
}

clear_cache() {
  keyctl purge user "$CACHE_KEY" >/dev/null 2>&1 || true
}

# ---------- SSH context (for ssh-tpm-agent) ----------

get_ssh_args() {
  local pid="${SSH_CLIENT_PID:-}"
  [[ -z "$pid" ]] && return 1
  [[ ! -r "/proc/$pid/cmdline" ]] && return 1

  local -a args=()
  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < "/proc/$pid/cmdline"

  [[ "${args[0]}" == "ssh" || "${args[0]}" == */ssh ]] || return 1

  local i=1
  local line=""
  while [[ $i -lt ${#args[@]} ]]; do
    local arg="${args[$i]}"
    if [[ "$arg" == -* ]]; then
      [[ -n "$line" ]] && echo "$line"
      line="$arg"
    else
      if [[ -n "$line" ]]; then
        line="$line $arg"
      else
        line="$arg"
      fi
    fi
    ((i++))
  done
  [[ -n "$line" ]] && echo "$line"
}

escape_pango() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# ---------- rofi prompt ----------
#
# Args: $1 = prompt label (default "PIN")
#       $2 = optional pango-formatted -mesg text
#       $3 = use_cache: "cache" enables kernel-keyring caching, anything
#            else disables it (Assuan callers like rbw/gpg-agent do their
#            own caching, and sharing one keyring slot across unrelated
#            secrets is wrong).
# Echoes PIN on success, returns non-zero on cancel.
rofi_prompt() {
  local prompt_label="${1:-PIN}"
  local mesg="${2:-}"
  local use_cache="${3:-}"

  local mesg_args=()
  [[ -n "$mesg" ]] && mesg_args=(-mesg "$mesg")

  local theme_file="/var/theme/config/rofi-theme"
  local theme_args=()
  if [[ -r "$theme_file" ]]; then
    local theme
    theme=$(cat "$theme_file")
    theme_args=(-theme "$theme")
  fi

  # Cached PIN menu (only in modes that opted in)
  if [[ "$use_cache" == "cache" ]]; then
    local cached_pin=""
    if cached_pin=$(get_cached_pin 2>/dev/null) && [[ -n "$cached_pin" ]]; then
      local choice
      choice=$(printf "OK\nCancel\nClear cache" | rofi -dmenu \
        -i \
        -no-custom \
        -no-fixed-num-lines \
        "${mesg_args[@]}" \
        "${theme_args[@]}" \
        2>/dev/null) || return 1

      case "$choice" in
        "OK")
          extend_cache
          printf '%s' "$cached_pin"
          return 0
          ;;
        "Cancel")
          return 1
          ;;
        "Clear cache")
          clear_cache
          ;;
      esac
    fi
  fi

  local result
  result=$(rofi -dmenu \
    -password \
    -p "$prompt_label" \
    -lines 0 \
    -no-fixed-num-lines \
    "${mesg_args[@]}" \
    "${theme_args[@]}" \
    < /dev/null 2>/dev/null) || return 1

  [[ -z "$result" ]] && return 1

  if [[ "$use_cache" == "cache" ]]; then
    cache_pin "$result"
  fi
  printf '%s' "$result"
}

# ---------- mode: SSH_ASKPASS ----------

askpass_main() {
  local ssh_args=""
  ssh_args=$(get_ssh_args 2>/dev/null | escape_pango) || ssh_args=""

  local mesg=""
  if [[ -n "$ssh_args" ]]; then
    mesg="<b>SSH:</b>
$ssh_args"
  fi

  local pin
  pin=$(rofi_prompt "PIN" "$mesg" cache) || exit 1
  printf '%s\n' "$pin"
}

# ---------- mode: Assuan pinentry ----------
#
# Spec (abridged): https://www.gnupg.org/documentation/manuals/assuan/
# Server greets with "OK ...", responds OK to most settings, and on
# GETPIN replies with "D <pin>" then "OK", or "ERR 83886179 cancelled".
# Data lines must percent-encode %, CR, LF.

assuan_decode() {
  # decode %HH escapes from SETDESC/SETPROMPT/SETERROR values
  printf '%b' "$(printf '%s' "$1" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"
}

assuan_encode_data() {
  # encode %, CR, LF for D-line output
  printf '%s' "$1" | sed -e 's/%/%25/g' -e 's/\r/%0D/g'
}

assuan_main() {
  printf 'OK Pleased to meet you\n'

  local desc="" prompt="PIN" error=""
  # title and keyinfo are accepted but unused by the rofi UI
  local _title="" _keyinfo=""

  local line cmd arg
  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ "$line" == *" "* ]]; then
      cmd="${line%% *}"
      arg="${line#* }"
    else
      cmd="$line"
      arg=""
    fi

    case "$cmd" in
      SETDESC)    desc="$(assuan_decode "$arg")";   printf 'OK\n' ;;
      SETPROMPT)  prompt="$(assuan_decode "$arg")"; printf 'OK\n' ;;
      SETERROR)   error="$(assuan_decode "$arg")";  printf 'OK\n' ;;
      SETTITLE)   _title="$(assuan_decode "$arg")";  printf 'OK\n' ;;
      SETKEYINFO) _keyinfo="$arg";                   printf 'OK\n' ;;

      OPTION|SETOK|SETCANCEL|SETNOTOK|SETTIMEOUT|SETQUALITYBAR|SETQUALITYBAR_TT|SETREPEAT|SETREPEATERROR|SETGENPIN|SETGENPIN_TT|CLEARPASSPHRASE|GETINFO)
        printf 'OK\n' ;;

      GETPIN)
        # Build rofi -mesg from desc/error
        local mesg=""
        if [[ -n "$error" ]]; then
          mesg="<b>$(printf '%s' "$error" | escape_pango)</b>"
          error=""
        fi
        if [[ -n "$desc" ]]; then
          [[ -n "$mesg" ]] && mesg+="
"
          mesg+="$(printf '%s' "$desc" | escape_pango)"
        fi

        local pin
        # No cache in Assuan mode: each caller (rbw, gpg-agent, ...)
        # asks for a different secret and does its own caching.
        if pin=$(rofi_prompt "${prompt:-PIN}" "$mesg" no-cache); then
          printf 'D %s\n' "$(assuan_encode_data "$pin")"
          printf 'OK\n'
        else
          printf 'ERR 83886179 Operation cancelled\n'
        fi
        ;;

      CONFIRM|MESSAGE)
        printf 'OK\n' ;;

      RESET)
        desc=""; prompt="PIN"; error=""; _title=""; _keyinfo=""
        printf 'OK\n' ;;

      NOP)
        printf 'OK\n' ;;

      BYE)
        printf 'OK closing connection\n'
        exit 0 ;;

      "")
        ;;

      *)
        printf 'OK\n' ;;
    esac
  done
}

# ---------- dispatch ----------

is_assuan_mode() {
  # Assuan/pinentry mode: no args, or first arg is a flag.
  # Real pinentry callers (rbw, gpg-agent) always lead with flags like
  #   --timeout 0 --ttyname /dev/pts/0 --display :0 --no-global-grab
  # Note we can't require *every* arg to start with '-', because flag
  # values ("0", "/dev/pts/0", ":0", ...) don't.
  #
  # SSH_ASKPASS mode: first arg is a bare prompt string (no leading '-').
  [[ $# -eq 0 || "${1:-}" == -* ]]
}

if is_assuan_mode "$@"; then
  assuan_main
else
  askpass_main
fi
