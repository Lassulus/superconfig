{ config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/desktops/qtile
    ../../2configs/pipewire.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/wine.nix
    ../../2configs/bitcoin.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/consul.nix
    ../../2configs/snapclient.nix
  ];

  krebs.build.host = config.krebs.hosts.shodan;

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  nix.trustedUsers = [ "root" "lass" ];
  system.stateVersion = "22.05";
}
