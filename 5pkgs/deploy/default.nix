{ writers }:
writers.writeDashBin "deploy" ''
  set -xeu
  export SYSTEM="$1"
  $(nix-build $HOME/sync/stockholm/lass/krops.nix --no-out-link --argstr name "$SYSTEM" -A deploy)
''
