{ pkgs }:
pkgs.writers.writeDashBin "install-system" ''
  set -efux
  SYSTEM=$1
  TARGET=$2
  # format
  if ! (sshn "$TARGET" -- mountpoint /mnt); then
    if ! (sshn "$TARGET" -- type -p nix); then
      nix run github:numtide/nixos-remote -- --stop-after-disko --store-paths "$(nix-build --no-out-link -I stockholm="$HOME"/sync/stockholm -I nixos-config="$HOME"/sync/stockholm/lass/1systems/"$SYSTEM"/physical.nix '<nixpkgs/nixos>' -A config.system.build.diskoNoDeps)" /dev/null "$TARGET"
    else
      disko=$(nix-build -I stockholm=$HOME/sync/stockholm -I secrets=$HOME/sync/stockholm/lass/2configs/tests/dummy-secrets -I nixos-config=$HOME/sync/stockholm/lass/1systems/$SYSTEM/physical.nix '<nixpkgs/nixos>' -A config.system.build.disko)
      NIX_SSHOPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' nix-copy-closure --to "$TARGET" "$disko"
      sshn -t "$TARGET" -- "$disko"
    fi
  fi

  # install dependencies
  sshn "$TARGET" << SSH
    if ! type -p git; then
      nix-channel --update
      nix-env -iA nixos.git
    fi
  SSH

  # populate
  $(nix-build --no-out-link "$HOME"/sync/stockholm/lass/krops.nix -A populate --argstr name "$SYSTEM" --argstr target "$TARGET"/mnt/var/src --arg force true)

  # install
  sshn "$TARGET" << SSH
    NIXOS_CONFIG=/var/src/nixos-config nixos-install --no-root-password -I /mnt/var/src
    nixos-enter -- nixos-rebuild -I /var/src switch --install-bootloader
    umount -R /mnt
    zpool export -fa
  SSH
''
