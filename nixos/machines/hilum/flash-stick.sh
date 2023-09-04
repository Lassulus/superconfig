#!/bin/sh
set -efux

disk=$1

cd "$(dirname "$0")"
export NIXPKGS_ALLOW_UNFREE=1
(umask 077; pass show admin/hilum/luks > /tmp/hilum.luks)
trap 'rm -f /tmp/hilum.luks' EXIT
echo "$disk" > /tmp/hilum-disk
trap 'rm -f /tmp/hilum-disk' EXIT

stockholm_root=$(git rev-parse --show-toplevel)
ssh root@localhost -t -- $(nix-build \
  --no-out-link \
  -I nixpkgs=/var/src/nixpkgs \
  -I stockholm="$stockholm_root" \
  -I secrets="$stockholm_root"/lass/2configs/tests/dummy-secrets \
  -E "with import <nixpkgs> {}; (pkgs.nixos [
    {
      luksPassFile = \"/tmp/hilum.luks\";
      mainDisk = \"$disk\";
      disko.rootMountPoint = \"/mnt/hilum\";
    }
    ./physical.nix
  ]).disko"
)
rm -f /tmp/hilum.luks
$(nix-build \
  --no-out-link \
  -I nixpkgs=/var/src/nixpkgs \
  "$stockholm_root"/lass/krops.nix -A populate \
  --argstr name hilum \
  --argstr target "root@localhost/mnt/hilum/var/src" \
  --arg force true
)
ssh root@localhost << SSH
set -efux
mkdir -p /mnt/hilum/etc
NIXOS_CONFIG=/mnt/hilum/var/src/nixos-config nixos-install --no-bootloader --no-root-password --root /mnt/hilum -I /var/src
nixos-enter --root /mnt/hilum -- nixos-rebuild -I /var/src switch --install-bootloader
umount -Rv /mnt/hilum
SSH
