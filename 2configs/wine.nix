{ config, pkgs, ... }:

let
  mainUser = config.users.extraUsers.mainUser;

in {
  users.users= {
    wine = {
      home = "/home/wine";
      useDefaultShell = true;
      extraGroups = [
        "audio"
        "video"
      ];
      createHome = true;
      packages = [
        pkgs.winePackages.minimal
      ];
      isNormalUser = true;
    };
  };
  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(wine) NOPASSWD: ALL
  '';
}
