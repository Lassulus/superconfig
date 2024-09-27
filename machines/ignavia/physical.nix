{ self, modulesPath, ... }:
{
  imports = [
    ./config.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk.nix
    self.inputs.nixos-hardware.nixosModules.framework-13th-gen-intel
  ];

  # fprintd is currently broken
  services.fprintd.enable = false;

  krebs.power-action.battery = "BAT1";

  networking.hostId = "deadbeef";

  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  hardware.opengl.enable = true;

  boot.initrd.availableKernelModules = [
    "nvme"
    "thunderbolt"
    "xhci_pci"
    "usbhid"
  ];
}
