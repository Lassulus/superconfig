{ config, pkgs, ... }:
{
  imports = [
    ../../configs
    ../../configs/retiolum.nix
    ../../configs/network-manager.nix
    ../../configs/syncthing.nix
  ];

  krebs.build.host = config.krebs.hosts.hilum;

  boot.loader.grub = {
    extraEntries = ''
      submenu isos {
        source /grub/autoiso.cfg
      }
    '';
    extraFiles."/grub/autoiso.cfg" = (
      pkgs.stdenv.mkDerivation {
        name = "autoiso.cfg";
        src = pkgs.grub2.src;
        phases = [
          "unpackPhase"
          "installPhase"
        ];
        installPhase = ''
          cp docs/autoiso.cfg $out
        '';
      }
    );
  };

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";

  boot.tmpOnTmpfs = true;
}
