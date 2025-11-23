{ pkgs, ... }:
{
  imports = [
    ./disk.nix
    ./config.nix
    ./gpd-fan.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.graphics.enable = true;
}
