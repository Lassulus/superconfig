#!/usr/bin/env bash
# Pick one of your live SSH agents (forwarded or local) and print an export line.
# Usage: eval "$(ssh-agent-pick)"

uid=$(id -u)
rt=${XDG_RUNTIME_DIR:-/run/user/$uid}
cands=()
labels=()

# local agents (configs/tpm2.nix, configs/phonetpm.nix, gpg-agent, gcr).
# rbw's agent is left out: listing keys blocks on a vault unlock prompt.
local_socks=(
  "$rt/ssh-tpm-agent.sock"
  "$rt/phonetpm/agent.sock"
  "$rt/gnupg/S.gpg-agent.ssh"
  "$rt/gcr/ssh"
)

# newest first: sshd creates a forwarded socket when the connection is established
while IFS= read -r -d '' line; do
  sock=${line#* }
  [ -S "$sock" ] || continue
  [ "$(stat -c %u "$sock")" = "$uid" ] || continue
  rc=0
  # timeout: an agent waiting on an unlock prompt must not hang the picker
  keys=$(SSH_AUTH_SOCK=$sock timeout 3 ssh-add -l 2>/dev/null) || rc=$?
  [ "$rc" -le 1 ] || continue # 2 = cannot connect (stale), 124 = timed out
  if [ "$rc" -eq 1 ]; then
    keys="(no identities)"
  else
    keys=$(printf '%s\n' "$keys" | awk '{ $1 = $2 = ""; $NF = ""; sub(/^ +/, ""); sub(/ +$/, ""); print }' | paste -sd, -)
  fi
  since=$(date -d "@${line%% *}" '+%F %T')
  case $sock in
    "$rt"/*) kind=local ;;
    *) kind=forwarded ;;
  esac
  cands+=("$sock")
  labels+=("$since  $kind  $keys  $sock")
done < <({
  # errexit applies in here: a failing find must not skip the next one
  find /tmp/ssh-* "$HOME/.ssh/agent" -maxdepth 1 -type s \( -name 'agent.*' -o -name '*.sshd.*' \) -printf '%T@ %p\0' || true
  find "${local_socks[@]}" -maxdepth 0 -type s -printf '%T@ %p\0' || true
} 2>/dev/null | sort -zrn)

if [ ${#cands[@]} -eq 0 ]; then
  echo "ssh-agent-pick: no live agent found" >&2
  exit 1
fi

if [ ${#cands[@]} -eq 1 ]; then
  choice=${cands[0]}
elif [ -t 2 ]; then
  sel=$(printf '%s\n' "${labels[@]}" | fzf --height=~10 --reverse --prompt='agent> ') || exit 1
  choice=${sel##* }
else
  PS3='agent> '
  select _ in "${labels[@]}"; do
    [ -n "${REPLY:-}" ] && [ "$REPLY" -ge 1 ] 2>/dev/null && [ "$REPLY" -le ${#cands[@]} ] || continue
    choice=${cands[REPLY - 1]}
    break
  done
fi

[ -n "${choice:-}" ] || exit 1
printf "export SSH_AUTH_SOCK='%s'\n" "$choice"
