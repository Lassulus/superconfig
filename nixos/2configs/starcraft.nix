{ config, pkgs, ... }: let
  mainUser = config.users.extraUsers.mainUser;
in {
  users.users= {
    starcraft = {
      isNormalUser = true;
      extraGroups = [
        "audio"
        "video"
      ];
      packages = [
        pkgs.wineWowPackages.minimal
        pkgs.winetricks
        pkgs.mpg123
      ];
    };
  };
  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(starcraft) NOPASSWD: ALL
  '';
}

