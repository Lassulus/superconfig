{ config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/installer-tor.nix
  ];

  # Basic installer configuration
  networking.hostName = "installer";
}