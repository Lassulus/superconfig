{ config, lib, pkgs, ... }:

{
  imports = [
    ../../.
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/baseX.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    ../../2configs/sync/sync.nix
    ../../2configs/games.nix
    ../../2configs/steam.nix
    ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    ../../2configs/bitcoin.nix
    ../../2configs/review.nix
    ../../2configs/dunst.nix
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
