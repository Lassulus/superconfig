#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nixos-generators

set -xefu

WD=$(realpath $(dirname "$0"))
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
nixos-generate -c "$WD"/test.nix -f vm-nogui --run "$@"
cd -
rm -r "$TMPDIR"
