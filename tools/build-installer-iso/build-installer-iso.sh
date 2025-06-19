#!/usr/bin/env bash
set -euo pipefail
set -x

# Default values
OUTPUT="installer.iso"
ARCH="x86_64-linux"  # Default to x86_64-linux for cross-compilation
VARS_DIR=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Build a NixOS installer ISO with custom vars appended.

OPTIONS:
  -o, --output FILE     Output ISO file (default: installer.iso)
  -a, --arch ARCH       Architecture: x86_64-linux or aarch64-linux (default: x86_64-linux)
  -v, --vars DIR        Directory containing vars to append to ISO
  -h, --help            Show this help message

EXAMPLE:
  $0 -o my-installer.iso -v ./my-vars -a x86_64-linux
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
    -v|--vars)
      VARS_DIR="$2"
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
BASE_ISO=$(nix build -L --no-link --print-out-paths "$FLAKE_ROOT#clanInternals.machines.$ARCH.installer.config.system.build.images.iso-installer")

if [ -z "$VARS_DIR" ]; then
  # No vars specified, just copy the base ISO
  echo "No vars directory specified, copying base ISO..."
  cp "$BASE_ISO"/iso/*.iso "$OUTPUT"
else
  # Append vars using xorriso - preserve boot structure
  echo "Appending vars from $VARS_DIR to ISO..."
  xorriso \
    -indev "$BASE_ISO"/iso/*.iso \
    -outdev "$OUTPUT" \
    -boot_image any replay \
    -map "$VARS_DIR" /vars \
    -commit_eject all
fi

echo "ISO created: $OUTPUT"