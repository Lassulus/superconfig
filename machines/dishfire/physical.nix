{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    ./config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "ata_piix" "virtio_pci" "xhci_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/84053adc-49bc-4e02-8a19-3838bf3a43fd";
      fsType = "ext4";
    };

  swapDevices = [ ];
}
