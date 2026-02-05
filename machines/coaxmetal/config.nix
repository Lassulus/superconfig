{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    ../../2configs/games.nix
    ../../2configs/steam.nix
    ../../2configs/wine.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/review.nix
  ];

  system.stateVersion = "24.05";
  krebs.build.host = config.krebs.hosts.coaxmetal;

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  documentation.nixos.enable = true;

  environment.systemPackages = [
    pkgs.android-tools
  ];
}
