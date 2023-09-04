{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    ./config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.initrd.luks.devices.luksroot.device = "/dev/sda3";

  networking.useDHCP = false;
  networking.interfaces.ens18.useDHCP = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5186edb1-9234-48ae-8679-61facb56b818";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/56D1-34A0";
    fsType = "vfat";
  };

}
