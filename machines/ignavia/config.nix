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
    ../../2configs/yggdrasil.nix
    ../../2configs/container-tests.nix
    ../../2configs/sunshine.nix
    # ../../2configs/print.nix
    # ../../2configs/br.nix
    # ../../2configs/c-base.nix
    { # clan backups playground
      imports = [
        self.inputs.clan-core.clanModules.borgbackup
      ];
      clanCore.state.teststate = {
        folders = [ "/home/lass/sync" ];
      };
      clan.borgbackup = {
        enable = true;
        destinations.mors.repo = "borg@mors.r:.";
      };
    }
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

  environment.systemPackages = [
    pkgs.gh
    pkgs.bank
  ];

  krebs.hosts.styx.nets.retiolum.tinc.extraConfig = "Address = 10.42.0.1 655";

  virtualisation.podman.enable = true;

  hardware.keyboard.qmk.enable = true;

  users.users.mainUser.extraGroups = [ "wireshark" ];
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark-qt;

}
