{
  self,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    # ../../2configs/baseX.nix
    ../../2configs/desktops/qtile/nixos.nix
    # ../../2configs/desktops/xmonad
    ../../2configs/power-action.nix
    ../../2configs/yubikey.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    # ../../2configs/games.nix
    ../../2configs/steam.nix
    # ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    ../../2configs/printing
    ../../2configs/auto-timezone.nix
    # ../../2configs/bitcoin.nix
    ../../2configs/review.nix
    ../../2configs/dunst.nix
    ../../2configs/yggdrasil.nix
    ../../2configs/container-tests.nix
    # ../../2configs/sunshine.nix
    # ../../2configs/br.nix
    # ../../2configs/c-base.nix
  ];

  system.stateVersion = "23.11";

  krebs.build.host = config.krebs.hosts.ignavia;

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

  environment.systemPackages = [
    pkgs.android-tools
    pkgs.gh
    self.packages.${pkgs.system}.bank
    pkgs.mycelium
    pkgs.tmate
    pkgs.claude-code
  ];

  krebs.hosts.styx.nets.retiolum.tinc.extraConfig = "Address = 10.42.0.1 655";

  virtualisation.podman.enable = true;

  hardware.keyboard.qmk.enable = true;

  users.users.mainUser.extraGroups = [ "wireshark" ];
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark-qt;

}
