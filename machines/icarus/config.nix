{ config, pkgs, ... }:

{
  imports = [
    ../../2configs
    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/desktops/xmonad
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/games.nix
    ../../2configs/bitcoin.nix
    ../../2configs/wine.nix
    ../../2configs/network-manager.nix
    ../../2configs/red-host.nix
    ../../2configs/ipfs.nix
    ../../2configs/snapclient.nix
    ../../2configs/consul.nix
    ../../2configs/autoupdate.nix
  ];

  krebs.build.host = config.krebs.hosts.icarus;

  # services.xrdp = {
  #   enable = true;
  #   defaultWindowManager = "xmonad";
  # };
  # krebs.iptables.tables.filter.INPUT.rules = [
  #   { predicate = "-p tcp --dport 3389"; target = "ACCEPT"; } # xrdp
  # ];

  environment.systemPackages = [ pkgs.chromium ];

  # users.users.lass.openssh.authorizedKeys = [ config.krebs.users.mic92.pubkey ];
  system.stateVersion = "22.05";
}
