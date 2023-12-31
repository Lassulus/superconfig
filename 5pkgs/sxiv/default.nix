{ nsxiv, writers }:

writers.writeDashBin "sxiv" ''
  set -efu
  tmpfile="''${TMPDIR:-/tmp}/nsxiv_pipe_$$"
  trap 'rm -f -- $tmpfile' EXIT

  if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
      echo "sxiv: No arguments provided" >&2; exit 1
    else
      # Consume stdin and put it in the temporal file
      cat > "$tmpfile"
    fi
  fi

  for arg in "$@"; do
    # if it's a pipe then drain it to $tmpfile
    [ -p "$arg" ] && cat "$arg" > "$tmpfile"
  done

  if [ -s "$tmpfile" ]; then
    ${nsxiv}/bin/nsxiv -q "$@" "$tmpfile" # -q to silence warnings
  else
    ${nsxiv}/bin/nsxiv "$@" # fallback
  fi
''
