{ config, lib, pkgs, ... }:

{
  virtualisation.libvirtd.enable = true;
  security.polkit.enable = true;

  krebs.iptables.tables.filter.INPUT.rules = [
    { v6 = false; predicate = "-i virbr0 -p udp -m udp --dport 53"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i virbr0 -p tcp -m tcp --dport 53"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i virbr0 -p udp -m udp --dport 67"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i virbr0 -p tcp -m tcp --dport 67"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.filter.FORWARD.rules = [
    { v6 = false; predicate = "-d 192.168.122.0/24 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED"; target = "ACCEPT"; }
    { v6 = false; predicate = "-s 192.168.122.0/24 -i virbr0"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i virbr0 -o virbr0"; target = "ACCEPT"; }
    { v6 = false; predicate = "-o virbr0"; target = "REJECT --reject-with icmp-port-unreachable"; }
    { v6 = false; predicate = "-i virbr0"; target = "REJECT --reject-with icmp-port-unreachable"; }
  ];
  krebs.iptables.tables.filter.OUTPUT.rules = [
    { v6 = false; predicate = "-o virbr0 -p udp -m udp --dport 68"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.nat.PREROUTING.rules = lib.mkBefore [
    { v6 = false; predicate = "-s 192.168.122.0/24"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    { v6 = false; predicate = "-s 192.168.122.0/24 -d 224.0.0.0/24"; target = "RETURN"; }
    { v6 = false; predicate = "-s 192.168.122.0/24 -d 255.255.255.255"; target = "RETURN"; }
    { v6 = false; predicate = "-s 192.168.122.0/24 ! -d 192.168.122.0/24"; target = "MASQUERADE"; }
    { v6 = false; predicate = "-s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp"; target = "MASQUERADE --to-ports 1024-65535"; }
    { v6 = false; predicate = "-s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp"; target = "MASQUERADE --to-ports 1024-65535"; }
  ];
}
