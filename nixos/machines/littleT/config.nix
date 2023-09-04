{ config, pkgs, ... }:

{
  imports = [
    ../../

    ../../2configs/retiolum.nix
    ../../2configs/blue-host.nix
    ../../2configs/green-host.nix
    ../../2configs/syncthing.nix
  ];

  networking.networkmanager.enable = true;
  networking.wireless.enable = mkForce false;
  time.timeZone = "Europe/Berlin";

  hardware.trackpoint = {
    enable = true;
    sensitivity = 220;
    speed = 0;
    emulateWheel = true;
  };

  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
  '';

  krebs.build.host = config.krebs.hosts.littleT;
}
