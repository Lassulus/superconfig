#!/usr/bin/env bash
set -euo pipefail
set -x

# Default values
ISO_FILE=""
MEMORY="2048"
CPUS="2"
ARCH=""
NOGRAPHIC=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] ISO_FILE

Boot an ISO file in a VM with automatic architecture detection.

OPTIONS:
  -m, --memory SIZE     Memory in MB (default: 2048)
  -c, --cpus COUNT      Number of CPU cores (default: 2)
  -a, --arch ARCH       Force architecture (x86_64 or aarch64)
  -n, --nographic       Run in text mode without graphics
  -h, --help            Show this help message

EXAMPLE:
  $0 installer.iso
  $0 -m 4096 -c 4 installer.iso
  $0 -a x86_64 installer.iso
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--memory)
      MEMORY="$2"
      shift 2
      ;;
    -c|--cpus)
      CPUS="$2"
      shift 2
      ;;
    -a|--arch)
      ARCH="$2"
      shift 2
      ;;
    -n|--nographic)
      NOGRAPHIC=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -z "$ISO_FILE" ]; then
        ISO_FILE="$1"
      else
        echo "Multiple ISO files specified"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Check if ISO file is provided
if [ -z "$ISO_FILE" ]; then
  echo "Error: ISO file not specified"
  usage
  exit 1
fi

# Check if ISO file exists
if [ ! -f "$ISO_FILE" ]; then
  echo "Error: ISO file '$ISO_FILE' not found"
  exit 1
fi

# Detect architecture if not specified
if [ -z "$ARCH" ]; then
  echo "Detecting ISO architecture..."
  ISO_INFO=$(file "$ISO_FILE")
  if echo "$ISO_INFO" | grep -q "aarch64"; then
    ARCH="aarch64"
  elif echo "$ISO_INFO" | grep -q "x86-64\|x86_64"; then
    ARCH="x86_64"
  else
    # Try to extract more info from the ISO
    ISO_LABEL=$(blkid -o value -s LABEL "$ISO_FILE" 2>/dev/null || echo "")
    if echo "$ISO_LABEL" | grep -q "aarch64"; then
      ARCH="aarch64"
    elif echo "$ISO_LABEL" | grep -q "x86"; then
      ARCH="x86_64"
    else
      echo "Could not detect architecture from ISO. Please specify with -a option."
      echo "Supported architectures: x86_64, aarch64"
      exit 1
    fi
  fi
fi

echo "Booting $ISO_FILE with $ARCH architecture..."
echo "Memory: $MEMORY MB, CPUs: $CPUS"

# Build QEMU command based on architecture
if [ "$ARCH" = "x86_64" ]; then
  echo "Starting x86_64 VM with EFI..."
  # Get the x86_64-linux UEFI firmware
  echo "Building x86_64-linux UEFI firmware..."
  UEFI_STORE_PATH=$(nix build --no-link --print-out-paths --system x86_64-linux nixpkgs#OVMF.fd)
  UEFI_FW="$UEFI_STORE_PATH/FV/OVMF.fd"
  if [ ! -f "$UEFI_FW" ]; then
    echo "Error: Could not find x86_64 UEFI firmware at $UEFI_FW"
    exit 1
  fi
  echo "Using UEFI firmware: $UEFI_FW"
  if [ "$NOGRAPHIC" = true ]; then
    exec qemu-system-x86_64 \
      -machine q35 \
      -cpu qemu64 \
      -m "$MEMORY" \
      -smp "$CPUS" \
      -accel tcg \
      -bios "$UEFI_FW" \
      -cdrom "$ISO_FILE" \
      -boot d \
      -nographic \
      -serial mon:stdio
  else
    exec qemu-system-x86_64 \
      -machine q35 \
      -cpu qemu64 \
      -m "$MEMORY" \
      -smp "$CPUS" \
      -accel tcg \
      -bios "$UEFI_FW" \
      -cdrom "$ISO_FILE" \
      -boot d
  fi
elif [ "$ARCH" = "aarch64" ]; then
  echo "Starting aarch64 VM..."
  # Get the aarch64-linux UEFI firmware
  echo "Building aarch64 UEFI firmware..."
  # Use the pre-built firmware path we know works
  UEFI_FW="/nix/store/2ciakp99mrcb3fx98j6ji0nxkxcyq5gy-OVMF-202505-fd/FV/QEMU_EFI.fd"
  if [ ! -f "$UEFI_FW" ]; then
    echo "Firmware not found in store, building..."
    UEFI_STORE_PATH=$(nix build --no-link --print-out-paths nixpkgs#OVMF-fd.aarch64-linux)
    UEFI_FW="$UEFI_STORE_PATH/FV/QEMU_EFI.fd"
  fi
  if [ ! -f "$UEFI_FW" ]; then
    echo "Error: Could not find aarch64 UEFI firmware at $UEFI_FW"
    exit 1
  fi
  echo "Using UEFI firmware: $UEFI_FW"
  if [ "$NOGRAPHIC" = true ]; then
    exec qemu-system-aarch64 \
      -machine virt \
      -cpu cortex-a57 \
      -m "$MEMORY" \
      -smp "$CPUS" \
      -accel tcg \
      -bios "$UEFI_FW" \
      -cdrom "$ISO_FILE" \
      -boot d \
      -nographic
  else
    exec qemu-system-aarch64 \
      -machine virt \
      -cpu cortex-a57 \
      -m "$MEMORY" \
      -smp "$CPUS" \
      -accel tcg \
      -bios "$UEFI_FW" \
      -cdrom "$ISO_FILE" \
      -boot d
  fi
else
  echo "Error: Unsupported architecture '$ARCH'"
  echo "Supported architectures: x86_64, aarch64"
  exit 1
fi
