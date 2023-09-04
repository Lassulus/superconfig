{ config, lib, pkgs, ... }:
{
  services.nginx.virtualHosts."docs.c3gsm.de" = {
    forceSSL = true;
    enableACME = true;
    locations."/".extraConfig = ''
      auth_basic "Restricted Content";
      auth_basic_user_file ${pkgs.writeText "flix-user-pass" ''
        c3gsm:$apr1$q9OrPI4C$7AY4EIp3J2Xc4eLMbPGE21
      ''};
      root /srv/http/docs.c3gsm.de;
    '';
  };

  services.nginx.virtualHosts."c3gsm.de" = {
    forceSSL = true;
    enableACME = true;
    locations."/".extraConfig = ''
      root /srv/http/c3gsm.de;
    '';
  };

  users.users.c3gsm-docs = {
    isNormalUser = true;
    home = "/srv/http/docs.c3gsm.de";
    createHome = true;
    homeMode = "750";
    useDefaultShell = true;
    group = "nginx";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlW1fvCrVXhVH/z76fXBWYR/qyecYTE9VOOkFLJ6OwG user@osmocom-dev"
    ];
  };

  users.users.c3gsm = {
    isNormalUser = true;
    home = "/srv/http/c3gsm.de";
    createHome = true;
    homeMode = "750";
    useDefaultShell = true;
    group = "nginx";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlW1fvCrVXhVH/z76fXBWYR/qyecYTE9VOOkFLJ6OwG user@osmocom-dev"
    ];
  };
}
