{ config, lib, pkgs, ... }:
{
  # Bridge interface for containers
  systemd.network.netdevs."10-ctr0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "ctr0";
    };
  };

  systemd.network.networks."10-ctr0" = {
    matchConfig.Name = "ctr0";
    address = [ "fd00:ctr::1/64" ];
    networkConfig.ConfigureWithoutCarrier = true;
  };

  # Exclude from NetworkManager
  networking.networkmanager.unmanaged = [ "ctr0" ];

  # IPv6 forwarding
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # Jool NAT64 kernel module
  boot.extraModulePackages = [ config.boot.kernelPackages.jool ];
  boot.kernelModules = [ "jool" ];

  systemd.services.jool = {
    description = "Jool NAT64";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.jool-cli}/bin/jool instance add --netfilter --pool6 64:ff9b::/96";
      ExecStop = "${pkgs.jool-cli}/bin/jool instance remove";
    };
  };

  # Firewall rules for container bridge
  krebs.iptables.tables.filter.FORWARD.rules = [
    { v6 = true; predicate = "-i ctr0"; target = "ACCEPT"; }
    { v6 = true; predicate = "-o ctr0 -m conntrack --ctstate RELATED,ESTABLISHED"; target = "ACCEPT"; }
  ];
}
