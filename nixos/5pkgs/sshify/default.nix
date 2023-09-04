{ pkgs }:
# usage: sshify prism.r -- curl ifconfig.me
pkgs.writers.writeBashBin "sshify" ''
  set -efu

  TMPDIR=$(mktemp -d)

  SSH_ARGS=()

  while [[ "$#" -gt 0 ]]; do
      case $1 in
          --)
            shift
            break
            ;;
          *)
            SSH_ARGS+=($1)
            ;;
      esac
      shift
  done

  if [[ "$#" -le 0 ]]; then
    echo no command specified
    exit 1
  fi

  RANDOM_HIGH_PORT=$(shuf -i 20000-65000 -n 1)

  cat << EOF >$TMPDIR/proxychains.conf
  [ProxyList]
  socks4  127.0.0.1 $RANDOM_HIGH_PORT
  EOF

  ssh -fNM -S "$TMPDIR/socket" -D "$RANDOM_HIGH_PORT" "''${SSH_ARGS[@]}"
  trap "ssh -S $TMPDIR/socket -O exit bla 2>/dev/null; rm -rf $TMPDIR >&2" EXIT

  ${pkgs.proxychains-ng}/bin/proxychains4 -q -f "$TMPDIR/proxychains.conf" "$@"
''
