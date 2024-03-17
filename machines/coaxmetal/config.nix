{ config, lib, pkgs, ... }:

{
  imports = [
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
    { # moonlight test env
      imports = [
        ../../2configs/sunshine.nix
        ../../2configs/mpv.nix
      ];
      users.users.moon = {
        isNormalUser = true;
        uid = 1338;
        extraGroups = [ "video" "audio" "input" "pipewire" ];
        home = "/home/moon";
        password = "moon";
        packages = with pkgs; [
          (retroarch.override { cores = [
            libretro.bsnes-hd
            libretro.mupen64plus
          ]; })
        ];
      };
      services.xserver.enable = true;
      services.xserver.displayManager.autoLogin = {
        enable = true;
        user = "moon";
      };
      services.xserver.desktopManager.xfce.enable = true;
      services.xserver.displayManager.defaultSession = lib.mkForce "xfce";
      services.xserver.displayManager.sessionCommands = ''
        tmux new-session -A -s sun -- sun
      '';
      environment.systemPackages = [
        pkgs.firefox-devedition
        pkgs.vulkan-tools
      ];
      systemd.user.services.sun = {
        wantedBy = [ "default.target" ];
        environment = {
          DISPLAY = ":0";
          XAUTHORITY = "/home/moon/.Xauthority";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.tmux}/bin/tmux new-session -A -s sun -- /run/current-system/sw/bin/sun";
          Restart = "always";
          RestartSec = 5;
        };
      };
    }
  ];

  system.stateVersion = "24.05";
  krebs.build.host = config.krebs.hosts.coaxmetal;

  programs.adb.enable = true;

  nix.settings.trusted-users = [ "root" "lass" ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  documentation.nixos.enable = true;
}
