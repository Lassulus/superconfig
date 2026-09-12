#!/usr/bin/env bash
set -euo pipefail

PROG="nat-share"

# Defaults
SUBNET_PREFIX="10.42.0"
NETMASK="24"
DHCP_NETMASK="255.255.255.0"
DHCP_START_HOST="10"
DHCP_END_HOST="254"
LEASE_TIME="12h"
UPSTREAM=""
IFACE=""
DNS_SERVER=""
BACKEND="auto"
PXE_ROOT=""
PXE_SCRIPT="netboot.ipxe"
HTTP=""
HTTP_PORT="8079"

usage() {
  cat >&2 <<EOF
Usage: $PROG [OPTIONS] <interface>

Start a DHCP + DNS (dnsmasq) NAT server on <interface>, sharing the host's
upstream internet connection with clients on that link. The interface is
unmanaged from NetworkManager while the server runs; every change (IP,
NetworkManager state, forwarding sysctl, firewall rules) is reverted on exit.

Runs in the foreground. Press Ctrl+C to stop and restore.

Options:
  -u, --upstream <iface>   Upstream/WAN interface to NAT through
                           (default: interface of the current default route)
  -s, --subnet <prefix>    /24 subnet prefix for the served link
                           (default: ${SUBNET_PREFIX}, gateway <prefix>.1)
      --range <start-end>  DHCP host range within the /24
                           (default: ${DHCP_START_HOST}-${DHCP_END_HOST})
      --lease <time>       DHCP lease time (default: ${LEASE_TIME})
      --dns <ip>           Upstream DNS server to forward to
                           (default: system resolv.conf)
      --pxe <dir>          Additionally boot PXE clients from <dir>. Handing
                           out the boot filename happens here (only the DHCP
                           server can); serving the files is delegated to
                           \`pxe-share --no-dhcp\`. <dir> should hold ipxe.efi
                           (UEFI x64), optionally ipxe32.efi /
                           undionly.kpxe, and ${PXE_SCRIPT}.
      --http               Have pxe-share serve the --pxe dir over HTTP as
                           well; requires --pxe. Needed for netboot payloads:
                           a kernel+initrd carrying a nix store is far too big
                           for TFTP.
      --http-port <port>   Port for --http (default: ${HTTP_PORT})
  -b, --backend <name>     Firewall backend: auto | iptables | nft
                           (default: auto-detect)
  -h, --help               Show this help
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -u | --upstream)
      UPSTREAM="$2"
      shift 2
      ;;
    -s | --subnet)
      SUBNET_PREFIX="$2"
      shift 2
      ;;
    --range)
      DHCP_START_HOST="${2%%-*}"
      DHCP_END_HOST="${2##*-}"
      shift 2
      ;;
    --lease)
      LEASE_TIME="$2"
      shift 2
      ;;
    --dns)
      DNS_SERVER="$2"
      shift 2
      ;;
    --pxe)
      PXE_ROOT="$2"
      shift 2
      ;;
    --http)
      HTTP=1
      shift
      ;;
    --http-port)
      HTTP_PORT="$2"
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
      if [[ -n $IFACE ]]; then
        echo "$PROG: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      IFACE="$1"
      shift
      ;;
  esac
done

if [[ -z $IFACE ]]; then
  echo "$PROG: no interface specified" >&2
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

if ! ip link show "$IFACE" >/dev/null 2>&1; then
  echo "$PROG: interface '$IFACE' does not exist" >&2
  exit 1
fi

if [[ -n $PXE_ROOT ]]; then
  if [[ ! -d $PXE_ROOT ]]; then
    echo "$PROG: pxe root '$PXE_ROOT' is not a directory" >&2
    exit 1
  fi
  # Absolute, because we re-exec through sudo from an unknown cwd.
  PXE_ROOT=$(cd "$PXE_ROOT" && pwd -P)
fi

if [[ -n $HTTP && -z $PXE_ROOT ]]; then
  echo "$PROG: --http only makes sense together with --pxe" >&2
  exit 1
fi

# Re-exec as root, preserving arguments.
if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" \
    ${UPSTREAM:+--upstream "$UPSTREAM"} \
    --subnet "$SUBNET_PREFIX" \
    --range "${DHCP_START_HOST}-${DHCP_END_HOST}" \
    --lease "$LEASE_TIME" \
    ${DNS_SERVER:+--dns "$DNS_SERVER"} \
    --backend "$BACKEND" \
    ${PXE_ROOT:+--pxe "$PXE_ROOT"} \
    ${HTTP:+--http --http-port "$HTTP_PORT"} \
    "$IFACE"
fi

GATEWAY="${SUBNET_PREFIX}.1"
DHCP_START="${SUBNET_PREFIX}.${DHCP_START_HOST}"
DHCP_END="${SUBNET_PREFIX}.${DHCP_END_HOST}"

# Autodetect the upstream interface from the default route.
if [[ -z $UPSTREAM ]]; then
  UPSTREAM=$(ip -4 route show default | awk '/default/ {print $5; exit}')
  if [[ -z $UPSTREAM ]]; then
    echo "$PROG: could not detect upstream interface; pass --upstream <iface>" >&2
    exit 1
  fi
fi

if [[ $UPSTREAM == "$IFACE" ]]; then
  echo "$PROG: upstream interface must differ from the served interface" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Firewall / NAT backend.
#
# iptables backend: INPUT/FORWARD are single chains, so inserting ACCEPT rules
# at the top preempts the firewall's reject.
#
# nftables backend: an ACCEPT in a separate base chain does NOT override a DROP
# in "inet nixos-fw" (only DROP is terminal across chains). So DHCP/DNS accepts
# must be inserted directly into the firewall's own chains, and NAT lives in a
# private table we can drop wholesale.
# ---------------------------------------------------------------------------
if [[ $BACKEND == auto ]]; then
  if command -v nft >/dev/null 2>&1 && nft list table inet nixos-fw >/dev/null 2>&1; then
    BACKEND=nft
  else
    BACKEND=iptables
  fi
fi

# Track what we changed so cleanup only reverts our own state.
NM_UNMANAGED=false
IP_ADDED=false
FORWARD_WAS=""
IPT_NAT_ADDED=false
IPT_FWD_IN_ADDED=false
IPT_FWD_OUT_ADDED=false
IPT_INPUT_OPENED=false
PXE_PID=""
DNSMASQ_PID=""
NFT_NAT_TABLE=false
FW_HANDLES=() # "chain handle" pairs inserted into inet nixos-fw

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

cleanup() {
  set +e
  echo ""
  echo "$PROG: restoring..."

  # dnsmasq ignores SIGINT outside debug mode, so stop it with SIGTERM.
  if [[ -n $DNSMASQ_PID ]]; then
    kill "$DNSMASQ_PID" 2>/dev/null
    wait "$DNSMASQ_PID" 2>/dev/null
  fi

  if [[ -n $PXE_PID ]]; then
    kill "$PXE_PID" 2>/dev/null
    wait "$PXE_PID" 2>/dev/null
  fi

  if [[ $BACKEND == iptables ]]; then
    $IPT_NAT_ADDED && iptables -t nat -D POSTROUTING -o "$UPSTREAM" -j MASQUERADE 2>/dev/null
    $IPT_FWD_IN_ADDED && iptables -D FORWARD -i "$UPSTREAM" -o "$IFACE" \
      -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
    $IPT_FWD_OUT_ADDED && iptables -D FORWARD -i "$IFACE" -o "$UPSTREAM" -j ACCEPT 2>/dev/null
    if $IPT_INPUT_OPENED; then
      iptables -D INPUT -i "$IFACE" -p udp --dport 67 -j ACCEPT 2>/dev/null
      iptables -D INPUT -i "$IFACE" -p udp --dport 53 -j ACCEPT 2>/dev/null
      iptables -D INPUT -i "$IFACE" -p tcp --dport 53 -j ACCEPT 2>/dev/null
    fi

  else
    local entry
    for entry in "${FW_HANDLES[@]}"; do
      # shellcheck disable=SC2086
      set -- $entry
      nft delete rule inet nixos-fw "$1" handle "$2" 2>/dev/null
    done
    $NFT_NAT_TABLE && nft delete table ip nat_share 2>/dev/null
  fi

  if [[ -n $FORWARD_WAS ]]; then
    echo "$FORWARD_WAS" >/proc/sys/net/ipv4/ip_forward 2>/dev/null
  fi

  $IP_ADDED && ip addr del "${GATEWAY}/${NETMASK}" dev "$IFACE" 2>/dev/null

  if $NM_UNMANAGED && command -v nmcli >/dev/null 2>&1; then
    nmcli device set "$IFACE" managed yes 2>/dev/null
  fi

  echo "$PROG: done"
}
# Signals only trigger a normal exit; cleanup runs exactly once via EXIT.
# (Ctrl+C reaches dnsmasq too, but it ignores SIGINT; bash's `wait` below is
# interruptible, so the INT trap fires immediately and cleanup SIGTERMs it.)
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Hand the interface off from NetworkManager, if present.
if command -v nmcli >/dev/null 2>&1 && nmcli -t -f RUNNING general >/dev/null 2>&1; then
  echo "$PROG: unmanaging $IFACE from NetworkManager"
  nmcli device set "$IFACE" managed no || true
  NM_UNMANAGED=true
fi

# Bring up the link with the gateway address.
echo "$PROG: configuring ${IFACE} as ${GATEWAY}/${NETMASK}"
ip link set "$IFACE" up
ip addr flush dev "$IFACE"
ip addr add "${GATEWAY}/${NETMASK}" dev "$IFACE"
IP_ADDED=true

# Enable IPv4 forwarding.
FORWARD_WAS=$(cat /proc/sys/net/ipv4/ip_forward)
echo 1 >/proc/sys/net/ipv4/ip_forward

# NAT + firewall openings.
echo "$PROG: enabling NAT via ${UPSTREAM} (${BACKEND} backend)"
if [[ $BACKEND == iptables ]]; then
  iptables -t nat -A POSTROUTING -o "$UPSTREAM" -j MASQUERADE
  IPT_NAT_ADDED=true
  # Insert at the top of FORWARD so a DROP policy / reject can't shadow us.
  iptables -I FORWARD -i "$UPSTREAM" -o "$IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
  IPT_FWD_IN_ADDED=true
  iptables -I FORWARD -i "$IFACE" -o "$UPSTREAM" -j ACCEPT
  IPT_FWD_OUT_ADDED=true
  # Let clients reach our DHCP (67) and DNS (53) despite the host firewall.
  iptables -I INPUT -i "$IFACE" -p udp --dport 67 -j ACCEPT
  iptables -I INPUT -i "$IFACE" -p udp --dport 53 -j ACCEPT
  iptables -I INPUT -i "$IFACE" -p tcp --dport 53 -j ACCEPT
  IPT_INPUT_OPENED=true

else
  # NAT masquerade in a private table (torn down wholesale on exit).
  nft add table ip nat_share
  nft add chain ip nat_share postrouting '{ type nat hook postrouting priority 100 ; }'
  nft add rule ip nat_share postrouting oifname "$UPSTREAM" masquerade
  NFT_NAT_TABLE=true

  # DHCP/DNS accepts must live inside the firewall's own input chain to beat
  # its drop; likewise forward accepts if the firewall filters forwarding.
  in_chain=$(nft_base_chain input)
  fwd_chain=$(nft_base_chain forward)
  if [[ -n $in_chain ]]; then
    fw_insert "$in_chain" iifname "$IFACE" udp dport '{ 53, 67 }' accept
    fw_insert "$in_chain" iifname "$IFACE" tcp dport 53 accept

  fi
  if [[ -n $fwd_chain ]]; then
    fw_insert "$fwd_chain" iifname "$UPSTREAM" oifname "$IFACE" ct state related,established accept
    fw_insert "$fwd_chain" iifname "$IFACE" oifname "$UPSTREAM" accept
  fi
fi

# DHCP + DNS via dnsmasq, bound only to the served interface/address.
DNS_OPTS=()
if [[ -n $DNS_SERVER ]]; then
  DNS_OPTS+=(--no-resolv "--server=${DNS_SERVER}")
fi

# PXE. Only the DHCP half belongs here: nothing but the DHCP server can tell a
# client what to boot. Serving the files (TFTP, and HTTP for payloads too big
# for TFTP) is pxe-share's job — the same tool that can do this on networks we
# don't own, where it answers as a proxy DHCP server instead. Here we already
# own port 67, so it runs with --no-dhcp and just serves, and opens its own
# firewall ports.
#
# Chainloaded in two steps: bare firmware is matched on its client
# architecture and handed an iPXE binary; iPXE itself (which sets DHCP option
# 175) is then handed the boot script. Without that split the firmware would
# be pointed back at iPXE forever.
PXE_OPTS=()
if [[ -n $PXE_ROOT ]]; then
  PXE_OPTS+=(
    "--dhcp-match=set:ipxe,175"
    "--dhcp-match=set:efi64,option:client-arch,7"
    "--dhcp-match=set:efi64,option:client-arch,9"
    "--dhcp-match=set:efi32,option:client-arch,6"
    "--dhcp-boot=tag:ipxe,${PXE_SCRIPT}"
    "--dhcp-boot=tag:!ipxe,tag:efi64,ipxe.efi"
    "--dhcp-boot=tag:!ipxe,tag:efi32,ipxe32.efi"
    "--dhcp-boot=tag:!ipxe,tag:!efi64,tag:!efi32,undionly.kpxe"
  )
  pxe-share --no-dhcp \
    ${HTTP:+--http --http-port "$HTTP_PORT"} \
    --script "$PXE_SCRIPT" \
    --backend "$BACKEND" \
    "$PXE_ROOT" "$IFACE" &
  PXE_PID=$!
fi

echo "$PROG: serving DHCP ${DHCP_START}-${DHCP_END} (lease ${LEASE_TIME}) on ${IFACE}"
echo "$PROG: press Ctrl+C to stop"
dnsmasq \
  --keep-in-foreground \
  --log-facility=- \
  --interface="$IFACE" \
  --bind-interfaces \
  --except-interface=lo \
  --listen-address="$GATEWAY" \
  --dhcp-authoritative \
  --dhcp-range="${DHCP_START},${DHCP_END},${DHCP_NETMASK},${LEASE_TIME}" \
  --dhcp-option=option:router,"$GATEWAY" \
  --dhcp-option=option:dns-server,"$GATEWAY" \
  "${DNS_OPTS[@]}" \
  "${PXE_OPTS[@]}" &
DNSMASQ_PID=$!
wait "$DNSMASQ_PID"
