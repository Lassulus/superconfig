{ config, lib, ... }:

let
  r_ip = config.krebs.build.host.nets.retiolum.ip4.addr;

in {
  imports = [
    ./privoxy.nix
  ];

  services.privoxy.listenAddress = "${r_ip}:8118";

  krebs.iptables = {
    tables = {
      filter.INPUT.rules = [
        { predicate = "-i retiolum -p tcp --dport 8118"; target = "ACCEPT"; }
        { predicate = "-i dns0 -p tcp --dport 8118"; target = "ACCEPT"; }
      ];
    };
  };
}
