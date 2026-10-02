{ lib, ... }:

{
  krebs.iptables.tables.filter.FORWARD.rules = [
    # { v6 = false; predicate = "-d 10.233.2.0/24 -o ve-+ -m conntrack --ctstate RELATED,ESTABLISHED"; target = "ACCEPT"; }
    # { v6 = false; predicate = "-s 10.233.2.0/24 -i ve-+"; target = "ACCEPT"; }
    {
      v6 = false;
      predicate = "-o ctr+ -m conntrack --ctstate RELATED,ESTABLISHED";
      target = "ACCEPT";
    }
    {
      v6 = false;
      predicate = "-i ctr+";
      target = "ACCEPT";
    }
    {
      v6 = false;
      predicate = "-o ve-+ -m conntrack --ctstate RELATED,ESTABLISHED";
      target = "ACCEPT";
    }
    {
      v6 = false;
      predicate = "-i ve-+";
      target = "ACCEPT";
    }
    # { v6 = false; predicate = "-i ve-+ -o ve-+"; target = "ACCEPT"; }
    # { v6 = false; predicate = "-o ve-+"; target = "REJECT --reject-with icmp-port-unreachable"; }
    # { v6 = false; predicate = "-i ve-+"; target = "REJECT --reject-with icmp-port-unreachable"; }
  ];
  krebs.iptables.tables.nat.PREROUTING.rules = lib.mkBefore [
    {
      v6 = false;
      predicate = "-i ctr+";
      target = "ACCEPT";
    }
    {
      v6 = false;
      predicate = "-i ve-+";
      target = "ACCEPT";
    }
  ];
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    # { v6 = false; predicate = "-o et0"; target = "MASQUERADE"; }

    {
      v6 = false;
      predicate = "-s 10.233.0.0/16 ! -d 10.233.0.0/16";
      target = "MASQUERADE";
    }
    # { v6 = false; predicate = "-s 10.233.2.0/24 -d 224.0.0.0/24"; target = "RETURN"; }
    # { v6 = false; predicate = "-s 10.233.2.0/24 -d 255.255.255.255"; target = "RETURN"; }
    # { v6 = false; predicate = "-s 10.233.2.0/24 ! -d 10.233.2.0/24"; target = "MASQUERADE"; }
    # { v6 = false; predicate = "-s 10.233.2.0/24 ! -d 10.233.2.0/24 -p tcp"; target = "MASQUERADE --to-ports 1024-65535"; }
    # { v6 = false; predicate = "-s 10.233.2.0/24 ! -d 10.233.2.0/24 -p udp"; target = "MASQUERADE --to-ports 1024-65535"; }
  ];
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault 1;
}
