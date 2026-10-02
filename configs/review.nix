{ config, pkgs, ... }:

let
  mainUser = config.users.extraUsers.mainUser;
in
{

  users.users.review = {
    isNormalUser = true;
    packages = [ pkgs.nixpkgs-review ];
  };
  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(review) NOPASSWD: ALL
  '';
}
