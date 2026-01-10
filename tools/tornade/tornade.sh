#!/usr/bin/env bash
set -euo pipefail

# Create temporary directory for this tor instance
TOR_DIR=$(mktemp -d -t tornade.XXXXXX)

# Generate random ports in ephemeral range (49152-65535) to avoid collisions
SOCKS_PORT=$((49152 + RANDOM % 16383))
CONTROL_PORT=$((SOCKS_PORT + 1))

# Track tor PID for cleanup
TOR_PID=""

# Cleanup function - must be defined before trap
cleanup() {
  if [ -n "$TOR_PID" ] && kill -0 "$TOR_PID" 2>/dev/null; then
    kill "$TOR_PID" 2>/dev/null || true
    wait "$TOR_PID" 2>/dev/null || true
  fi
  rm -rf "$TOR_DIR"
}
trap cleanup EXIT INT TERM

# Create tor configuration
cat > "$TOR_DIR/torrc" <<EOF
DataDirectory $TOR_DIR/data
SocksPort 127.0.0.1:$SOCKS_PORT
ControlPort 127.0.0.1:$CONTROL_PORT
Log notice file $TOR_DIR/tor.log
RunAsDaemon 0

# Hidden service optimizations - longer timeouts for .onion addresses
CircuitBuildTimeout 60
LearnCircuitBuildTimeout 0
SocksTimeout 300

# Keep circuits stable for longer sessions
MaxCircuitDirtiness 900
KeepalivePeriod 60
EOF

# Start tor in background - suppress output to avoid protocol interference
tor -f "$TOR_DIR/torrc" >/dev/null 2>&1 &
TOR_PID=$!

# Wait for Tor to bootstrap (up to 90 seconds)
for i in {1..90}; do
  if [ -f "$TOR_DIR/tor.log" ] && grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
    break
  fi
  # If log file doesn't exist after 5 seconds, tor likely failed to start
  if [ "$i" -eq 5 ] && [ ! -f "$TOR_DIR/tor.log" ]; then
    exit 1
  fi
  sleep 1
done

# Final check - if still not ready after all attempts, exit
if ! grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
  exit 1
fi

# Check if we're on Darwin
if [[ "$(uname)" == "Darwin" ]]; then
  if [[ "$1" == "ssh" ]]; then
    # Direct SSH call - use old behavior
    shift # remove 'ssh' from arguments
    exec ssh -o ProxyCommand="nc -x 127.0.0.1:$SOCKS_PORT %h %p" "$@"
  else
    # Other commands - create SSH wrapper and add to PATH
    SSH_WRAPPER="$TOR_DIR/ssh"
    cat > "$SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
# SSH wrapper that routes through Tor on Darwin
exec /usr/bin/ssh -o ProxyCommand="nc -x 127.0.0.1:$SOCKS_PORT %h %p" "\$@"
EOF
    chmod +x "$SSH_WRAPPER"
    export PATH="$TOR_DIR:$PATH"
  fi
fi

# Execute the command
export TORSOCKS_TOR_PORT=$SOCKS_PORT
export TOR_CONTROL_PORT=$CONTROL_PORT
exec torsocks "$@"
