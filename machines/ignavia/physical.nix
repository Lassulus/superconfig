{
  self,
  modulesPath,
  pkgs,
  lib,
  ...
}:
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

  networking.hostId = "deadbeef";

  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  hardware.graphics.enable = true;
  hardware.acpilight.enable = true;

  # Use latest kernel (7.0) for better Strix Point GPU support
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Disable MES (Micro Engine Scheduler) - known to cause GPU ring hangs on RDNA3+
  # The hang manifests as: screen goes off 1-2s, comes back but frozen
  boot.kernelParams = [ "amdgpu.mes=0" ];

  # iwlwifi (Intel AX210) crashes after suspend with 0x5A5A5A5A in all registers
  # (PCIe device doesn't come back from low-power state)
  # enable_ini=0 disables the new UEFI-style firmware loading which fails on resume
  boot.extraModprobeConfig = "options iwlwifi enable_ini=0";

  boot.initrd.availableKernelModules = [
    "nvme"
    "thunderbolt"
    "xhci_pci"
    "usbhid"
  ];
}
