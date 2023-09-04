{ config, lib, pkgs, ... }:

{
  imports = [
    ./config.nix
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-SanDisk_SSD_G5_BICS4_20248F446514";
  boot.loader.grub.efiInstallAsRemovable = true;

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/ee5c9099-17fa-401e-852e-67cb4ae068f4";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/EAA5-88A9";
      fsType = "vfat";
    };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ATTR{address}=="3c:7c:3f:7e:e2:39", NAME="et0"
    SUBSYSTEM=="net", ATTR{address}=="00:e0:4c:78:91:50", NAME="int0"
  '';
}
