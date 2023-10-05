{ config, lib, pkgs, ... }:
{
  systemd.services.usb_tether = {
    script = ''
      ${pkgs.android-tools}/bin/adb -s QV770FAMEK wait-for-device
      ${pkgs.android-tools}/bin/adb -s QV770FAMEK shell svc usb setFunctions rndis
    '';
  };
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{PRODUCT}=="fce/320d/510", TAG+="systemd", ENV{SYSTEMD_WANTS}="usb_tether.service"
  '';
  systemd.network.networks.android = {
    matchConfig.Name = "enp0s20u1";
    DHCP = "yes";
  };
}
