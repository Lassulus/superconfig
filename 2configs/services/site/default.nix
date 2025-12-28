{ config, pkgs, ... }:
{
  security.acme = {
    certs."lassul.us" = {
      group = "lasscert";
    };
  };

  users.groups.lasscert.members = [
    "exim"
    "nginx"
  ];

  services.nginx.virtualHosts."lassul.us" = {
    addSSL = true;
    enableACME = true;
    default = true;
    locations."/".extraConfig = ''
      root /srv/http/lassul.us;
    '';
    locations."= /retiolum-hosts.tar.bz2".extraConfig = ''
      alias ${config.krebs.tinc.retiolum.hostsArchive};
    '';
    locations."= /hosts".extraConfig = ''
      alias ${pkgs.krebs-hosts_combined};
    '';
    locations."= /retiolum.hosts".extraConfig = ''
      alias ${pkgs.krebs-hosts-retiolum};
    '';
    locations."= /wireguard-key".extraConfig = ''
      alias ${pkgs.writeText "prism.wg" config.krebs.hosts.prism.nets.wiregrill.wireguard.pubkey};
    '';
    locations."= /krebspage".extraConfig = ''
      default_type "text/html";
      alias ${pkgs.krebspage}/index.html;
    '';
    locations."= /ssh.pub".extraConfig = ''
      alias ${pkgs.writeText "pub" config.krebs.users.lass-yubikey.pubkey};
    '';
    locations."= /gpg.pub".extraConfig = ''
      alias ${pkgs.writeText "pub" config.krebs.users.lass-yubikey.pgp.pubkeys.default};
    '';
    locations."= /ip".extraConfig = ''
      return 200 '$remote_addr';
    '';
  };
}
