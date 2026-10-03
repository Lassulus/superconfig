#!/usr/bin/env bash
# Pick one of your live forwarded SSH agents and print an export line.
# Usage: eval "$(ssh-agent-pick)"

uid=$(id -u)
cands=()
labels=()

# newest first: sshd creates the socket when the connection is established
while IFS= read -r -d '' line; do
  sock=${line#* }
  [ -S "$sock" ] || continue
  [ "$(stat -c %u "$sock")" = "$uid" ] || continue
  rc=0
  keys=$(SSH_AUTH_SOCK=$sock ssh-add -l 2>/dev/null) || rc=$?
  [ "$rc" -le 1 ] || continue # 2 = cannot connect (stale)
  if [ "$rc" -eq 1 ]; then
    keys="(no identities)"
  else
    keys=$(printf '%s\n' "$keys" | awk '{ $1 = $2 = ""; $NF = ""; sub(/^ +/, ""); sub(/ +$/, ""); print }' | paste -sd, -)
  fi
  since=$(date -d "@${line%% *}" '+%F %T')
  cands+=("$sock")
  labels+=("$since  $keys  $sock")
done < <(find /tmp/ssh-* "$HOME/.ssh/agent" -maxdepth 1 -type s \( -name 'agent.*' -o -name '*.sshd.*' \) \
  -printf '%T@ %p\0' 2>/dev/null | sort -zrn)

if [ ${#cands[@]} -eq 0 ]; then
  echo "ssh-agent-pick: no live forwarded agent found" >&2
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
