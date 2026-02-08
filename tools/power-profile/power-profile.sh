#!/usr/bin/env bash

set -euo pipefail

# Power profiles in watts (stapm/sustained limit)
PROFILE_LOW=3
PROFILE_NORMAL=15
PROFILE_HIGH=28

# State file for eww integration (ryzenadj -i doesn't work on all CPUs)
STATE_FILE="/tmp/power-profile-state"

usage() {
  cat <<EOF
Usage: power-profile <profile|watts>

Profiles:
  low     - ${PROFILE_LOW}W TDP (battery saving)
  normal  - ${PROFILE_NORMAL}W TDP (balanced)
  high    - ${PROFILE_HIGH}W TDP (performance)

Or specify watts directly:
  power-profile 10   # Set 10W TDP

Burst limits are automatically calculated:
  slow = stapm × 1.2
  fast = stapm × 1.5

Examples:
  power-profile low
  power-profile normal
  power-profile high
  power-profile 5
EOF
}

set_tdp() {
  local name=$1
  local stapm=$2
  # Calculate burst limits (using integer math, *10 then /10 to simulate decimals)
  local slow=$(( (stapm * 12) / 10 ))
  local fast=$(( (stapm * 15) / 10 ))

  local stapm_mw=$((stapm * 1000))
  local slow_mw=$((slow * 1000))
  local fast_mw=$((fast * 1000))

  echo "Setting power profile:"
  echo "  STAPM (sustained): ${stapm}W"
  echo "  Slow limit:        ${slow}W"
  echo "  Fast limit:        ${fast}W"
  /run/wrappers/bin/sudo /run/current-system/sw/bin/ryzenadj --stapm-limit="$stapm_mw" --slow-limit="$slow_mw" --fast-limit="$fast_mw"

  # Write state for eww integration
  echo "$name $stapm" > "$STATE_FILE"
  echo "Done."
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  low)
    set_tdp "low" "$PROFILE_LOW"
    ;;
  normal)
    set_tdp "normal" "$PROFILE_NORMAL"
    ;;
  high)
    set_tdp "high" "$PROFILE_HIGH"
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      set_tdp "custom" "$1"
    else
      echo "Error: Unknown profile '$1'"
      usage
      exit 1
    fi
    ;;
esac
