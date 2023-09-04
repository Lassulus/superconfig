{ config, lib, pkgs, ... }:
let
  tcpports = [
    4443 # jitsi
    64738 # murmur
  ];
  udpports = [
    10000 # jitsi
    64738 # murmur
  ];
  target = "orange.r";
in
{
  networking.firewall.allowedTCPPorts = tcpports;
  networking.firewall.allowedUDPPorts = udpports;
  services.nginx.streamConfig = ''
    ${lib.concatMapStringsSep "\n" (port: ''
      server {
        listen [::]:${toString port};
        listen ${toString port};
        proxy_pass ${target}:${toString port};
      }
    '') tcpports}
  '';

  krebs.iptables.tables.nat.PREROUTING.rules = lib.flatten (map (port: [
    { predicate = "-p udp --dport ${toString port}"; target = "DNAT --to-destination ${config.krebs.hosts.orange.nets.retiolum.ip4.addr}:${toString port}"; v6 = false; }
    { predicate = "-p udp --dport ${toString port}"; target = "DNAT --to-destination [${config.krebs.hosts.orange.nets.retiolum.ip6.addr}]:${toString port}"; v4 = false; }
  ]) udpports);

  services.nginx.virtualHosts."jitsi.lassul.us" = {
    enableACME = true;
    acmeFallbackHost = "${target}";
    addSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "https://${target}";
    };
  };
}
