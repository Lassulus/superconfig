{ config, lib, pkgs, ... }:
{
  services.murmur = {
    enable = true;
    # allowHtml = false;
    bandwidth = 10000000;
    registerName = "lassul.us";
    autobanTime = 30;
    sslCert = "/var/lib/acme/lassul.us/cert.pem";
    sslKey = "/var/lib/acme/lassul.us/key.pem";
    extraConfig = ''
      opusthreshold=0
      # rememberchannelduration=10000
    '';
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 64738"; target = "ACCEPT";}
    { predicate = "-p udp --dport 64738"; target = "ACCEPT";}
  ];

  # services.botamusique = {
  #   enable = true;
  #   settings = {
  #     server.host = "lassul.us";
  #     bot.auto_check_updates = false;
  #     bot.max_track_duration = 360;
  #     webinterface.enabled = true;
  #   };
  # };

  services.nginx.virtualHosts."lassul.us" = {
    enableACME = true;
  };
  security.acme.certs."lassul.us" = {
    group = "lasscert";
  };
  users.groups.lasscert.members = [
    "nginx"
    "murmur"
  ];

  # services.nginx.virtualHosts."bota.r" = {
  #   locations."/" = {
  #     proxyPass = "http://localhost:8181";
  #   };
  # };
}
