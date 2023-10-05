#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nixos-generators

set -efu

WD=$(dirname "$0")
nixos-generate -I stockholm="$WD"/../../.. -c "$WD"/config.nix -f vm-nogui --run
