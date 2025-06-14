#!/usr/bin/env bash
set -euo pipefail

# Create temporary directory for this tor instance
TOR_DIR=$(mktemp -d -t tornade.XXXXXX)
trap 'rm -rf "$TOR_DIR"' EXIT

# Generate random ports
SOCKS_PORT=$((9050 + RANDOM % 1000))
CONTROL_PORT=$((SOCKS_PORT + 1))

# Create tor configuration
cat > "$TOR_DIR/torrc" <<EOF
DataDirectory $TOR_DIR/data
SocksPort 127.0.0.1:$SOCKS_PORT
ControlPort 127.0.0.1:$CONTROL_PORT
Log notice file $TOR_DIR/tor.log
RunAsDaemon 0

# Performance optimizations
CircuitBuildTimeout 10
LearnCircuitBuildTimeout 0
NumEntryGuards 3
KeepalivePeriod 60
SocksTimeout 60

# Don't wait for descriptor downloads
UseMicroDescriptors 0
EOF

# Start tor in background
echo "Starting isolated Tor instance on port $SOCKS_PORT..." >&2
tor -f "$TOR_DIR/torrc" &
TOR_PID=$!

# Function to cleanup tor process
cleanup() {
  if kill -0 "$TOR_PID" 2>/dev/null; then
    echo "Stopping Tor instance..." >&2
    kill "$TOR_PID" 2>/dev/null || true
    wait "$TOR_PID" 2>/dev/null || true
  fi
  rm -rf "$TOR_DIR"
}
trap cleanup EXIT INT TERM

# Wait for tor to be ready
echo "Waiting for Tor to establish circuits..." >&2
# Check frequently at first, then slow down
for i in {1..60}; do
  if grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
    echo "Tor is ready!" >&2
    break
  fi
  # Check every 0.1s for first 2 seconds, then every 0.5s
  if [ "$i" -le 20 ]; then
    sleep 0.1
  else
    sleep 0.5
  fi
done

if ! grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
  echo "Error: Tor failed to establish circuits" >&2
  exit 1
fi

# Check if we're trying to run SSH on macOS
if [[ "$1" == "ssh" ]] && [[ "$(uname)" == "Darwin" ]]; then
  # On macOS, use ProxyCommand instead of torsocks due to SIP
  shift # remove 'ssh' from arguments
  exec ssh -o ProxyCommand="nc -x 127.0.0.1:$SOCKS_PORT %h %p" "$@"
else
  # For other commands or non-macOS systems, use torsocks
  export TORSOCKS_TOR_PORT=$SOCKS_PORT
  exec torsocks "$@"
fi