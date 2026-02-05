{ config, pkgs, ... }:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/browsers.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    # ../../2configs/bitcoin.nix
    # ../../2configs/review.nix
    # ../../2configs/dunst.nix
    ../../2configs/br.nix
    # ../../2configs/c-base.nix
  ];

  system.stateVersion = "22.11";

  krebs.build.host = config.krebs.hosts.aergia;

  environment.systemPackages = [
    pkgs.android-tools
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.pulseaudio.package = pkgs.pulseaudioFull;

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  documentation.nixos.enable = true;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  boot.tmp.cleanOnBoot = true;
  programs.noisetorch.enable = true;
}
