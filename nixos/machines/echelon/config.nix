{ config, pkgs, ... }:
{
  imports = [
    ../../.
    ../../2configs/retiolum.nix
    ../../2configs/tor-initrd.nix
    ../../2configs/syncthing.nix
    ../../2configs/green-host.nix
  ];

  krebs.build.host = config.krebs.hosts.echelon;

  boot.tmpOnTmpfs = true;

}

