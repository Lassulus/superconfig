#!/usr/bin/env bash
set -euo pipefail

# Default SSH port
SSH_PORT="${SSH_PORT:-22}"

# Create temporary directory for this tor instance
TOR_DIR=$(mktemp -d -t tor-ssh-service.XXXXXX)
trap 'rm -rf "$TOR_DIR"' EXIT

# Generate random ports
SOCKS_PORT=$((9050 + RANDOM % 1000))
CONTROL_PORT=$((SOCKS_PORT + 1))

# Create hidden service directory with proper permissions
mkdir -p "$TOR_DIR/hidden_service"
chmod 700 "$TOR_DIR/hidden_service"

# Create tor configuration
cat > "$TOR_DIR/torrc" <<EOF
DataDirectory $TOR_DIR/data
SocksPort 127.0.0.1:$SOCKS_PORT
ControlPort 127.0.0.1:$CONTROL_PORT
Log notice file $TOR_DIR/tor.log
RunAsDaemon 0

# Hidden service configuration
HiddenServiceDir $TOR_DIR/hidden_service
HiddenServicePort 22 127.0.0.1:$SSH_PORT

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

echo "Starting Tor hidden service for SSH..."
echo "SSH port: $SSH_PORT"
echo "SOCKS port: $SOCKS_PORT"
echo ""

# Start tor in background
tor -f "$TOR_DIR/torrc" &
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

# Wait for tor to bootstrap
echo "Waiting for Tor to bootstrap..."
for i in {1..300}; do
  if grep -q "Bootstrapped 100%" "$TOR_DIR/tor.log" 2>/dev/null; then
    echo "Tor bootstrapped successfully!"
    break
  fi
  if [ "$i" -eq 300 ]; then
    echo "Error: Tor failed to bootstrap"
    exit 1
  fi
  sleep 0.5
done

# Wait for hidden service to be created
echo "Waiting for hidden service..."
for i in {1..60}; do
  if [ -f "$TOR_DIR/hidden_service/hostname" ]; then
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Error: Hidden service hostname not created"
    exit 1
  fi
  sleep 1
done

# Display the onion address
ONION_ADDRESS=$(cat "$TOR_DIR/hidden_service/hostname")
echo ""
echo "==============================================="
echo "Tor SSH hidden service is running!"
echo ""
echo "Onion address: $ONION_ADDRESS"
echo ""

# Generate QR code for easy copying
echo "QR Code for the onion address:"
qrencode -t UTF8 "$ONION_ADDRESS"
echo ""

echo "To connect from another machine:"
echo "  torify ssh $ONION_ADDRESS"
echo ""
echo "Or with a specific user:"
echo "  torify ssh user@$ONION_ADDRESS"
echo ""
echo "Press Ctrl+C to stop the service"
echo "==============================================="
echo ""

# Keep the service running
while true; do
  if ! kill -0 "$TOR_PID" 2>/dev/null; then
    echo "Tor process died unexpectedly"
    exit 1
  fi
  sleep 5
done