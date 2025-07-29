#!/usr/bin/env bash
set -euo pipefail
set -x

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

# Performance and reliability optimizations
CircuitBuildTimeout 15
LearnCircuitBuildTimeout 0
NumEntryGuards 8
KeepalivePeriod 60
SocksTimeout 120

# Reliability settings
MaxCircuitDirtiness 600
NewCircuitPeriod 30
UseEntryGuards 1
EOF

# Start tor in background - suppress output to avoid protocol interference
tor -f "$TOR_DIR/torrc" >/dev/null 2>&1 &
TOR_PID=$!

# Function to cleanup tor process
cleanup() {
  if kill -0 "$TOR_PID" 2>/dev/null; then
    kill "$TOR_PID" 2>/dev/null || true
    wait "$TOR_PID" 2>/dev/null || true
  fi
  rm -rf "$TOR_DIR"
}
trap cleanup EXIT INT TERM

# Retry up to 5 times to establish circuits
for attempt in 1 2 3 4 5; do
  
  if [ $attempt -gt 1 ]; then
    # Kill previous tor instance and restart
    kill "$TOR_PID" 2>/dev/null || true
    wait "$TOR_PID" 2>/dev/null || true
    tor -f "$TOR_DIR/torrc" >/dev/null 2>&1 &
    TOR_PID=$!
  fi
  
  # Check frequently at first, then slow down - longer timeout per attempt
  for i in {1..120}; do
    # Check if log file exists and contains the success message
    if [ -f "$TOR_DIR/tor.log" ] && grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
      # Success - exit both loops
      break 2
    fi
    # If log file doesn't exist after 2 seconds, tor likely failed to start
    if [ "$i" -eq 20 ] && [ ! -f "$TOR_DIR/tor.log" ]; then
      # Log file wasn't created after 2 seconds - tor likely failed completely
      # Exit with failure immediately rather than retrying
      break
    fi
    # Check every 0.1s for first 2 seconds, then every 0.5s
    if [ "$i" -le 20 ]; then
      sleep 0.1
    else
      sleep 0.5
    fi
  done
  
  # This attempt failed, continue to next attempt
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
