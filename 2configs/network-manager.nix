{
  self,
  pkgs,
  lib,
  ...
}:
{
  networking.wireless.enable = lib.mkForce false;

  networking.networkmanager = {
    ethernet.macAddress = "random";
    wifi.macAddress = "random";
    enable = true;
    unmanaged = [
      "docker*"
      "vboxnet*"
    ];
  };
  systemd.services.NetworkManager-wait-online.enable = false;
  users.users.mainUser = {
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [
      gnome-keyring
      dconf
    ];
  };
  environment.systemPackages = [
    self.packages.${pkgs.system}.nm-dmenu
    pkgs.wirelesstools
  ];
}
