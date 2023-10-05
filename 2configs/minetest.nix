{ pkgs, ... }: let

in {
  services.minetest-server = {
    enable = true;
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 30000"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 30000"; target = "ACCEPT"; }
  ];
}
