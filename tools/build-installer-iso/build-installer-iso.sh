#!/usr/bin/env bash
set -euo pipefail
set -x

# Default values
OUTPUT="installer.iso"
ARCH="x86_64-linux"  # Default to x86_64-linux for cross-compilation
CONFIG_DIR=""
FLAKE_URL=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Build a NixOS installer ISO with custom configuration.

OPTIONS:
  -o, --output FILE     Output ISO file (default: installer.iso)
  -a, --arch ARCH       Architecture: x86_64-linux or aarch64-linux (default: x86_64-linux)
  -c, --config DIR      Configuration directory containing installer-config.json and files/
  -f, --flake URL       Flake URL to install automatically (creates minimal config)
  -h, --help            Show this help message

EXAMPLES:
  $0 -o my-installer.iso -f github:user/nixos-config
  $0 -o my-installer.iso -c ./installer-config

Configuration Directory Structure:
installer-config/
├── installer-config.json          # Configuration file
└── files/                         # Files to copy to target system
    ├── etc/
    │   └── resolv.conf            # Gets copied to /etc/resolv.conf
    └── root/
        └── .ssh/
            └── authorized_keys    # Gets copied to /root/.ssh/authorized_keys

JSON Configuration Format:
{
  "flakeUrl": "github:user/nixos-config",
  "fileMetadata": {
    "/etc/resolv.conf": {
      "owner": "root:root",
      "permissions": "644"
    },
    "/root/.ssh/authorized_keys": {
      "owner": "root:root",
      "permissions": "600"
    }
  }
}

Default file metadata: owner=root:root, permissions=400
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -a|--arch)
      ARCH="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_DIR="$2"
      shift 2
      ;;
    -f|--flake)
      FLAKE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Build the base ISO
echo "Building base ISO for $ARCH..."
BASE_ISO=$(nix build -L --no-link --print-out-paths "$FLAKE_ROOT#nixosConfigurations.installer-$ARCH.config.system.build.images.iso-installer")

# Determine what to append to the ISO
if [ -n "$FLAKE_URL" ]; then
  # Create minimal config for flake URL
  echo "Creating minimal configuration for flake URL: $FLAKE_URL"
  TEMP_CONFIG_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_CONFIG_DIR"' EXIT

  cat > "$TEMP_CONFIG_DIR/installer-config.json" <<EOF
{
  "flakeUrl": "$FLAKE_URL"
}
EOF

  echo "Appending flake configuration to ISO..."
  xorriso \
    -indev "$BASE_ISO"/iso/*.iso \
    -outdev "$OUTPUT" \
    -boot_image any replay \
    -map "$TEMP_CONFIG_DIR/installer-config.json" /installer-config.json \
    -commit_eject all

elif [ -n "$CONFIG_DIR" ]; then
  # Use provided configuration directory
  echo "Appending configuration from $CONFIG_DIR to ISO..."

  if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: Configuration directory '$CONFIG_DIR' not found"
    exit 1
  fi

  # Build xorriso command with all necessary mappings
  XORRISO_ARGS=(
    -indev "$BASE_ISO"/iso/*.iso
    -outdev "$OUTPUT"
    -boot_image any replay
  )

  # Add installer-config.json if it exists
  if [ -f "$CONFIG_DIR/installer-config.json" ]; then
    XORRISO_ARGS+=(-map "$CONFIG_DIR/installer-config.json" /installer-config.json)
  fi

  # Add files directory if it exists
  if [ -d "$CONFIG_DIR/files" ]; then
    XORRISO_ARGS+=(-map "$CONFIG_DIR/files" /files)
  fi

  XORRISO_ARGS+=(-commit_eject all)

  xorriso "${XORRISO_ARGS[@]}"

else
  # No configuration specified, just copy the base ISO
  echo "No configuration specified, copying base ISO..."
  cp "$BASE_ISO"/iso/*.iso "$OUTPUT"
fi

echo "ISO created: $OUTPUT"