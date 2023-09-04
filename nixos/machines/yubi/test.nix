{ config, lib, pkgs, ... }:
{
  imports = [
    ./config.nix
  ];
  virtualisation.emptyDiskImages = [
    8000
  ];
  virtualisation.memorySize = 1024;
}
