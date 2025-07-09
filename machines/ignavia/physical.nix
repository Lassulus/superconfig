{ self, modulesPath, pkgs, ... }:
{
  imports = [
    ./config.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk.nix
    self.inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  services.fprintd.enable = true;
  services.fwupd.enable = true;
  services.fwupd.extraRemotes = [ "lvfs-testing" ];
  # Might be necessary once to make the update succeed
  # services.fwupd.uefiCapsuleSettings.DisableCapsuleUpdateOnDisk = true;
  # we need fwupd 1.9.7 to downgrade the fingerprint sensor firmware
  # we only need to downgrade the firmware once, so we can remove this once we have done that
  # services.fwupd.package = (import (builtins.fetchTarball {
  #   url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
  #   sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
  # }) {
  #   inherit (pkgs) system;
  # }).fwupd;

  krebs.power-action.battery = "BAT1";

  networking.hostId = "deadbeef";

  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  hardware.graphics.enable = true;
  hardware.acpilight.enable = true;

  boot.initrd.availableKernelModules = [
    "nvme"
    "thunderbolt"
    "xhci_pci"
    "usbhid"
  ];
}
