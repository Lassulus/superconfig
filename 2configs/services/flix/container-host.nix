{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.yellow = {
    sshKey = "${config.krebs.secret.directory}/yellow.sync.key";
    startCommand = ''
      until /run/wrappers/bin/ping -c1 github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --flake github:lassulus/superconfig#yellow switch
    '';
  };
  containers.yellow.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/yellow/state";
    isReadOnly = false;
  };
  containers.yellow.bindMounts."/var/download" = {
    hostPath = "/var/download";
    isReadOnly = false;
  };
  # krebs.iptables.tables.filter.FORWARD.rules = [
  #   { predicate = "-d ${config.krebs.hosts.yellow.nets.retiolum.ip4.addr} -p tcp --dport 8000 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; v6 = false; }
  #   { predicate = "-d ${config.krebs.hosts.yellow.nets.retiolum.ip6.addr} -p tcp --dport 8000 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; v4 = false; }
  # ];
  # krebs.iptables.tables.nat.PREROUTING.rules = [
  #   { predicate = "-p tcp --dport 2"; target = "DNAT --to-destination ${config.krebs.hosts.radio.nets.retiolum.ip4.addr}:8000"; v6 = false; }
  #   { predicate = "-p tcp --dport 2"; target = "DNAT --to-destination ${config.krebs.hosts.radio.nets.retiolum.ip6.addr}:8000"; v4 = false; }
  # ];
  networking.firewall.allowedTCPPorts = [ 8096 8920 ];
  networking.firewall.allowedUDPPorts = [ 1900 7359 ];
  containers.yellow.forwardPorts = [
    { hostPort = 8096; containerPort = 8096; protocol = "tcp"; }
    { hostPort = 8920; containerPort = 8920; protocol = "tcp"; }
    { hostPort = 1900; containerPort = 1900; protocol = "udp"; }
    { hostPort = 7359; containerPort = 7359; protocol = "udp"; }
  ];

  services.nginx.virtualHosts."flix.lassul.us" = {
    # forceSSL = true;
    # enableACME = true;
    locations."/" = {
      proxyPass = "http://yellow.r:8096";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
