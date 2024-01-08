{ self, config, pkgs, ... }:

{
  imports = [
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    # ../../2configs/baseX.nix
    ../../2configs/desktops/qtile
    ../../2configs/yubikey.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    # ../../2configs/games.nix
    ../../2configs/steam.nix
    # ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    ../../2configs/print.nix
    ../../2configs/br.nix
    # ../../2configs/bitcoin.nix
    ../../2configs/review.nix
    ../../2configs/dunst.nix
    ../../2configs/sunshine.nix
    # ../../2configs/print.nix
    # ../../2configs/br.nix
    # ../../2configs/c-base.nix
  ];

  system.stateVersion = "23.11";

  krebs.build.host = config.krebs.hosts.ignavia;

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
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  boot.cleanTmpDir = true;
  programs.noisetorch.enable = true;


}
