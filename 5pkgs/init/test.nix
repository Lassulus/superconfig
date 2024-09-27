{ lib, pkgs, ... }:
{
  virtualisation.emptyDiskImages = [
    8000
  ];
  virtualisation.memorySize = 1500;
  boot.tmpOnTmpfs = true;

  environment.systemPackages = [
    (pkgs.callPackage ./default.nix { })
  ];
  services.mingetty.autologinUser = lib.mkForce "root";
}
