{ config, lib, pkgs, ... }:
{
  services.murmur = {
    enable = true;
    allowHtml = false;
    bandwidth = 10000000;
    registerName = "lassul.us";
    autobanTime = 30;
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 64738"; target = "ACCEPT";}
    { predicate = "-p udp --dport 64738"; target = "ACCEPT";}
  ];

  systemd.services.docker-mumble-web.serviceConfig = {
    StandardOutput = lib.mkForce "journal";
    StandardError = lib.mkForce "journal";
  };
  virtualisation.oci-containers.containers.mumble-web = {
    image = "rankenstein/mumble-web:0.5";
    environment = {
      MUMBLE_SERVER = "lassul.us:64738";
    };
    ports = [
      "64739:8080"
    ];
  };

  services.nginx.virtualHosts."mumble.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:64739";
      proxyWebsockets = true;
    };
  };
}
