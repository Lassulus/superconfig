{ config, lib, pkgs, ... }:
{
  services.consul = {
    enable = true;
    # dropPrivileges = false;
    webUi = true;
    # interface.bind = "retiolum";
    extraConfig = {
      bind_addr = config.krebs.build.host.nets.retiolum.ip4.addr;
      bootstrap_expect = 3;
      server = true;
      # retry_join = config.services.consul.extraConfig.start_join;
      retry_join = lib.mapAttrsToList (n: h:
        lib.head h.nets.retiolum.aliases
      ) (lib.filterAttrs (n: h: h.consul) config.krebs.hosts);
      rejoin_after_leave = true;

      # try to fix random lock loss on leader reelection
      retry_interval = "3s";
    };
  };

  environment.etc."consul.d/testservice.json".text = builtins.toJSON {
    service = {
      name = "testing";
    };
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i retiolum -p tcp --dport 8300"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p tcp --dport 8301"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p udp --dport 8301"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p tcp --dport 8302"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p udp --dport 8302"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p tcp --dport 8400"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p tcp --dport 8500"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p tcp --dport 8600"; target = "ACCEPT"; }
    { predicate = "-i retiolum -p udp --dport 8500"; target = "ACCEPT"; }
  ];
}
