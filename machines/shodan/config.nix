{ config, ... }:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/desktops/qtile/nixos.nix
    ../../2configs/pipewire.nix
    ../../2configs/network-manager.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/consul.nix
    ../../2configs/snapclient.nix
  ];

  krebs.build.host = config.krebs.hosts.shodan;

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  nix.trustedUsers = [
    "root"
    "lass"
  ];
  system.stateVersion = "22.05";
}
