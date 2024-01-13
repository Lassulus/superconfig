{ config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    # ../../2configs/desktops/lib/x11.nix
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
        ../../2configs/pipewire.nix
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

  krebs.build.host = config.krebs.hosts.coaxmetal;

  environment.systemPackages = with pkgs; [
    brain
    bank
    l-gen-secrets
    (pkgs.writeDashBin "deploy" ''
      set -eu
      export SYSTEM="$1"
      $(nix-build $HOME/sync/stockholm/lass/krops.nix --no-out-link --argstr name "$SYSTEM" -A deploy)
    '')
    (pkgs.writeDashBin "usb-tether-on" ''
      adb shell su -c service call connectivity 33 i32 1 s16 text
    '')
    (pkgs.writeDashBin "usb-tether-off" ''
      adb shell su -c service call connectivity 33 i32 0 s16 text
    '')
  ];

  programs.adb.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  nix.trustedUsers = [ "root" "lass" ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  documentation.nixos.enable = true;
}
