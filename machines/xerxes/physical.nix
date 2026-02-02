{ pkgs, ... }:
{
  imports = [
    ./disk.nix
    ./config.nix
    ./gpd-fan.nix
    ./gpd-win-mini-2025-pipewire.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.graphics.enable = true;

  # Disable Bluetooth USB autosuspend to prevent hardware errors/disconnects
  # Disable VPE (Video Processing Engine) to fix black screen after suspend/resume
  # on AMD Strix APUs. VPE fails to reset properly causing IB test timeouts.
  # https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2065365
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=0
    options amdgpu ip_block_mask=0xfffff7ff
  '';

  services.logind.powerKey = "suspend";
}
