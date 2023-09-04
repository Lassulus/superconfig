{ config, lib, pkgs, ... }:

{
  imports = [
    <stockholm/lass>

    <stockholm/lass/2configs/mouse.nix>
    <stockholm/lass/2configs/retiolum.nix>
    <stockholm/lass/2configs/baseX.nix>
    <stockholm/lass/2configs/pipewire.nix>
    <stockholm/lass/2configs/exim-retiolum.nix>
    <stockholm/lass/2configs/browsers.nix>
    <stockholm/lass/2configs/programs.nix>
    <stockholm/lass/2configs/wine.nix>
    <stockholm/lass/2configs/bitcoin.nix>
    <stockholm/lass/2configs/yellow-mounts/samba.nix>
    <stockholm/lass/2configs/fetchWallpaper.nix>
    <stockholm/lass/2configs/consul.nix>
    <stockholm/lass/2configs/snapclient.nix>
  ];

  krebs.build.host = config.krebs.hosts.shodan;

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  nix.trustedUsers = [ "root" "lass" ];
  system.stateVersion = "22.05";
}
