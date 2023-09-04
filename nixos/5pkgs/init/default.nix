{ pkgs, lib, vgname ? "vgname", luksmap ? "luksmap", ... }:

with lib;

pkgs.writeScriptBin "init" ''
  #!/usr/bin/env nix-shell
  #! nix-shell -i bash -p cryptsetup gptfdisk jq libxfs
  set -xefuo pipefail

  disk=$1

  if mount | grep -q "$disk"; then
    echo "target device is already mounted, bailout"
    exit 2
  fi

  bootdev="$disk"2
  luksdev="$disk"3
  luksmap=/dev/mapper/${luksmap}

  vgname=${vgname}


  rootdev=/dev/mapper/${vgname}-root
  homedev=/dev/mapper/${vgname}-home

  read -p "LUKS Password: " lukspw

  #
  # partitioning
  #

  # http://en.wikipedia.org/wiki/GUID_Partition_Table
  # undo:
  #   dd if=/dev/zero bs=512 count=34 of=/dev/sda
  # TODO zero last 34 blocks (lsblk -bno SIZE /dev/sda)
  if ! test "$(blkid -o value -s PTTYPE "$disk")" = gpt; then
    sgdisk -og "$disk"
    sgdisk -n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 "$disk"
    sgdisk -n 2:4096:+1G -c 2:"EFI System Partition" -t 2:ef00 "$disk"
    sgdisk -n 3:0:0 -c 3:"LUKS container" -t 3:8300 "$disk"
  fi

  if ! test "$(blkid -o value -s PARTLABEL "$luksdev")" = "LUKS container"; then
    echo zonk2
    exit 23
  fi

  if ! cryptsetup isLuks "$luksdev"; then
    # aes xts-plain64
    echo -n "$lukspw" | cryptsetup luksFormat "$luksdev" - \
        -h sha512 \
        --iter-time 5000
  fi

  if ! test -e "$luksmap"; then
    echo "$lukspw" | cryptsetup luksOpen "$luksdev" "$(basename "$luksmap")" -
  fi

  if ! test "$(blkid -o value -s TYPE "$luksmap")" = LVM2_member; then
    pvcreate "$luksmap"
  fi

  if ! vgdisplay -s "$vgname"; then vgcreate "$vgname" "$luksmap"; fi

  lvchange -a y /dev/mapper/"$vgname"

  if ! test -e "$rootdev"; then lvcreate -L 3G -n root "$vgname"; fi

  #
  # formatting
  #

  if ! test "$(blkid -o value -s TYPE "$bootdev")" = vfat; then
    mkfs.vfat "$bootdev"
  fi

  if ! test "$(blkid -o value -s TYPE "$rootdev")" = xfs; then
    mkfs.xfs "$rootdev"
  fi

  if ! test "$(lsblk -n -o MOUNTPOINT "$rootdev")" = /mnt; then
    mkdir -p /mnt
    mount "$rootdev" /mnt
  fi
  if ! test "$(lsblk -n -o MOUNTPOINT "$bootdev")" = /mnt/boot; then
    mkdir -m 0000 -p /mnt/boot
    mount "$bootdev" /mnt/boot
  fi

  #
  # dependencies for stockholm
  #

  # TODO: get sentinal file from target_path
  mkdir -p /mnt/var/src
  touch /mnt/var/src/.populate

  #
  # print all the infos
  #

  gdisk -l "$disk"
  lsblk "$disk"

  echo READY.
''
