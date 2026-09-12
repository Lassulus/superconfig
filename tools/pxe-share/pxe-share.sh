#!/usr/bin/env bash
set -euo pipefail

PROG="pxe-share"

# Defaults
MODE="proxy"
HTTP_WANTED=""
HTTP_ROOT=""
HTTP_PORT="8079"
PXE_SCRIPT="netboot.ipxe"
BACKEND="auto"
IFACE=""
ROOT=""

usage() {
  cat >&2 <<EOF
Usage: $PROG [OPTIONS] <dir> <interface>

Serve PXE network boot from <dir> on <interface>.

By default this is a *proxy* DHCP server: it answers only the PXE boot
questions (which boot file to fetch) and never hands out addresses or DNS, so
it can run on a network whose DHCP server belongs to somebody else — a router,
an office LAN — without fighting it. The existing server keeps assigning IPs.

Nothing about the interface is reconfigured; only firewall rules are added,
and they are removed again on exit.

Runs in the foreground. Press Ctrl+C to stop and restore.

Options:
      --no-dhcp            Do not answer DHCP at all; only serve the files
                           (TFTP, and HTTP with --http). Use when another DHCP
                           server on the link already points clients at us,
                           e.g. \`nat-share --pxe\`, which owns port 67 itself.
      --http               Also serve <dir> over HTTP, on --http-port. Needed
                           for netboot payloads: a kernel+initrd carrying a
                           nix store is far too big for TFTP.
      --http-port <port>   Port for --http (default: ${HTTP_PORT})
      --script <name>      iPXE script handed to iPXE (default: ${PXE_SCRIPT})
  -b, --backend <name>     Firewall backend: auto | iptables | nft
                           (default: auto-detect)
  -h, --help               Show this help

<dir> should hold ipxe.efi (UEFI x64), optionally ipxe32.efi / undionly.kpxe
for other client architectures, and ${PXE_SCRIPT}.
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-dhcp)
      MODE="serve-only"
      shift
      ;;
    --http)
      # A plain flag on purpose: an optional argument here is ambiguous next
      # to the positional <dir> <interface> and silently eats the interface.
      HTTP_WANTED=1
      shift
      ;;
    --http-port)
      HTTP_PORT="$2"
      shift 2
      ;;
    --script)
      PXE_SCRIPT="$2"
      shift 2
      ;;
    -b | --backend)
      BACKEND="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "$PROG: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z $ROOT ]]; then
        ROOT="$1"
      elif [[ -z $IFACE ]]; then
        IFACE="$1"
      else
        echo "$PROG: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z $ROOT || -z $IFACE ]]; then
  echo "$PROG: need both <dir> and <interface>" >&2
  usage
  exit 1
fi

case $BACKEND in
  auto | iptables | nft) ;;
  *)
    echo "$PROG: invalid backend '$BACKEND' (expected auto|iptables|nft)" >&2
    exit 1
    ;;
esac

if [[ ! -d $ROOT ]]; then
  echo "$PROG: '$ROOT' is not a directory" >&2
  exit 1
fi
# Absolute, because we re-exec through sudo from an unknown cwd.
ROOT=$(cd "$ROOT" && pwd -P)

if [[ -n $HTTP_WANTED ]]; then
  HTTP_ROOT="$ROOT"
fi

if ! ip link show "$IFACE" >/dev/null 2>&1; then
  echo "$PROG: interface '$IFACE' does not exist" >&2
  exit 1
fi

# Re-exec as root, preserving arguments.
if [[ $EUID -ne 0 ]]; then
  reexec=()
  if [[ $MODE == serve-only ]]; then
    reexec+=(--no-dhcp)
  fi
  if [[ -n $HTTP_WANTED ]]; then
    reexec+=(--http --http-port "$HTTP_PORT")
  fi
  reexec+=(--script "$PXE_SCRIPT" --backend "$BACKEND" "$ROOT" "$IFACE")
  exec sudo -- "$0" "${reexec[@]}"
fi

if [[ $BACKEND == auto ]]; then
  if command -v nft >/dev/null 2>&1 && nft list table inet nixos-fw >/dev/null 2>&1; then
    BACKEND=nft
  else
    BACKEND=iptables
  fi
fi

# Proxy-DHCP has to answer from the address the clients can reach us on, and
# dnsmasq wants that subnet in --dhcp-range to scope the proxy offer.
ADDR=""
if [[ $MODE == proxy ]]; then
  ADDR=$(ip -4 -brief addr show dev "$IFACE" | awk '{print $3}' | cut -d/ -f1 | head -n1)
  if [[ -z $ADDR ]]; then
    echo "$PROG: $IFACE has no IPv4 address; proxy DHCP needs one (or use --no-dhcp)" >&2
    exit 1
  fi
fi

# Track what we changed so cleanup only reverts our own state.
IPT_RULES=()
FW_HANDLES=() # "chain handle" pairs inserted into inet nixos-fw
HTTP_PID=""

# Name of the "inet nixos-fw" base chain registered to the given hook, if any.
nft_base_chain() {
  nft list table inet nixos-fw 2>/dev/null | awk -v h="hook $1 " '
    /chain [A-Za-z0-9_.-]+ \{/ { name = $2 }
    index($0, h) { print name; exit }
  '
}

# Insert a rule at the top of an "inet nixos-fw" chain, remembering its handle.
fw_insert() {
  local chain=$1
  shift
  local out handle
  out=$(nft --handle --echo insert rule inet nixos-fw "$chain" "$@" 2>/dev/null) || return 1
  handle=$(printf '%s\n' "$out" | grep -oE 'handle [0-9]+' | grep -oE '[0-9]+' | tail -n1)
  [[ -n $handle ]] && FW_HANDLES+=("$chain $handle")
}

# Open a port on the served interface in whichever backend is active.
open_port() {
  local proto=$1 port=$2
  if [[ $BACKEND == iptables ]]; then
    iptables -I INPUT -i "$IFACE" -p "$proto" --dport "$port" -j ACCEPT
    IPT_RULES+=("$proto $port")
  else
    local chain
    chain=$(nft_base_chain input)
    [[ -n $chain ]] && fw_insert "$chain" iifname "$IFACE" "$proto" dport "$port" accept
  fi
}

cleanup() {
  set +e
  echo ""
  echo "$PROG: restoring..."

  if [[ -n $HTTP_PID ]]; then
    kill "$HTTP_PID" 2>/dev/null
    wait "$HTTP_PID" 2>/dev/null
  fi

  local entry
  for entry in "${IPT_RULES[@]}"; do
    # shellcheck disable=SC2086
    set -- $entry
    iptables -D INPUT -i "$IFACE" -p "$1" --dport "$2" -j ACCEPT 2>/dev/null
  done
  for entry in "${FW_HANDLES[@]}"; do
    # shellcheck disable=SC2086
    set -- $entry
    nft delete rule inet nixos-fw "$1" handle "$2" 2>/dev/null
  done

  echo "$PROG: done"
}
trap cleanup EXIT INT TERM

# TFTP is always ours. Only the initial request hits UDP/69; dnsmasq then
# transfers from an ephemeral port, whose return traffic conntrack already
# accepts as ESTABLISHED.
open_port udp 69
if [[ $MODE == proxy ]]; then
  # 67 for the proxy offer, 4011 for the PXE client's follow-up request.
  open_port udp 67
  open_port udp 4011
fi
if [[ -n $HTTP_ROOT ]]; then
  open_port tcp "$HTTP_PORT"
fi

DNSMASQ_OPTS=(
  --keep-in-foreground
  --log-facility=-
  --interface="$IFACE"
  --bind-interfaces
  --except-interface=lo
  # No DNS: somebody else's network already has one.
  --port=0
  --enable-tftp
  "--tftp-root=${ROOT}"
)

if [[ $MODE == proxy ]]; then
  # Chainloaded in two steps: bare firmware is matched on its client
  # architecture and handed an iPXE binary; iPXE itself (which sets DHCP
  # option 175) is then handed the boot script. Without that split the
  # firmware would be pointed back at iPXE forever.
  #
  # ",proxy" is what makes this coexist with the network's real DHCP server:
  # dnsmasq replies with boot information only, never with a lease.
  DNSMASQ_OPTS+=(
    "--dhcp-range=${ADDR},proxy"
    "--dhcp-match=set:ipxe,175"
    "--dhcp-match=set:efi64,option:client-arch,7"
    "--dhcp-match=set:efi64,option:client-arch,9"
    "--dhcp-match=set:efi32,option:client-arch,6"
    "--pxe-service=tag:!ipxe,x86-64_EFI,Network boot,ipxe.efi"
    "--pxe-service=tag:!ipxe,IA32_EFI,Network boot,ipxe32.efi"
    "--pxe-service=tag:!ipxe,x86PC,Network boot,undionly.kpxe"
    "--dhcp-boot=tag:ipxe,${PXE_SCRIPT}"
  )
  echo "$PROG: proxy DHCP on ${IFACE} (${ADDR}) — not assigning addresses"
else
  echo "$PROG: serving files only on ${IFACE} (no DHCP)"
fi

echo "$PROG: serving TFTP from ${ROOT} (boot script ${PXE_SCRIPT})"

if [[ -n $HTTP_ROOT ]]; then
  # darkhttpd follows the symlinks in the served root into /nix/store, so the
  # tree can point at the store instead of copying a multi-GB initrd around.
  echo "$PROG: serving HTTP from ${HTTP_ROOT} on port ${HTTP_PORT}"
  darkhttpd "$HTTP_ROOT" --port "$HTTP_PORT" &
  HTTP_PID=$!
fi

echo "$PROG: press Ctrl+C to stop"

# dnsmasq must not be a foreground child: a trap set while bash blocks on an
# external command is deferred until that command returns, and sudo runs us in
# its own pty/process group so the terminal's SIGINT never reaches dnsmasq
# either. The result was a Ctrl+C that did nothing at all. Backgrounding it and
# blocking in `wait` (a builtin, so handlers run immediately) means the signal
# is forwarded on, dnsmasq exits, and the EXIT trap tears down the firewall
# rules and darkhttpd.
dnsmasq "${DNSMASQ_OPTS[@]}" &
DNSMASQ_PID=$!
trap 'kill -TERM "$DNSMASQ_PID" 2>/dev/null' INT TERM
wait "$DNSMASQ_PID"
