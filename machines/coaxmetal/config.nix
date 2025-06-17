{
  self,
  config,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
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

  programs.adb.enable = true;

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
    self.inputs.clan-core.packages.x86_64-linux.clan-vm-manager
  ];
}
