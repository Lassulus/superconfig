{ config, lib, pkgs, ... }:
{
  # ipv6 from vodafone is really really flaky
  boot.kernel.sysctl."net.ipv6.conf.et0.disable_ipv6" = 1;
  systemd.network.networks."50-et0" = {
    matchConfig.Name = "et0";
    DHCP = "ipv4";
    # dhcpV4Config.UseDNS = false;
    # dhcpV6Config.UseDNS = false;
    linkConfig = {
      RequiredForOnline = "routable";
    };
    networkConfig = {
      LinkLocalAddressing = "no";
    };
    # dhcpV6Config = {
    #   PrefixDelegationHint = "::/60";
    # };
    # networkConfig = {
    #   IPv6AcceptRA = true;
    # };
    # ipv6PrefixDelegationConfig = {
    #   Managed = true;
    # };
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  systemd.network.networks."50-int0" = {
    name = "int0";
    address = [
      "10.42.0.1/24"
    ];
    networkConfig = {
      # IPForward = "yes";
      # IPMasquerade = "both";
      ConfigureWithoutCarrier = true;
      DHCPServer = "yes";
      # IPv6SendRA = "yes";
      # DHCPPrefixDelegation = "yes";
    };
    dhcpServerStaticLeases = [
      {
        dhcpServerStaticLeaseConfig = {
          Address = "10.42.0.4";
          MACAddress = "3c:2a:f4:22:28:37";
        };
      }
    ];
  };
  networking.networkmanager.unmanaged = [ "int0" ];
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i int0"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.filter.FORWARD.rules = [
    { predicate = "-i int0"; target = "ACCEPT"; }
    { predicate = "-o int0"; target = "ACCEPT"; }
    { predicate = "-p ipv6-icmp"; target = "ACCEPT"; v4 = false; }
  ];
  krebs.iptables.tables.nat.PREROUTING.rules = lib.mkBefore [
    { v6 = false; predicate = "-s 10.42.0.0/24"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    { v6 = false; predicate = "-s 10.42.0.0/24"; target = "MASQUERADE"; }
  ];

  networking.domain = "gg23";

  networking.useHostResolvConf = false;
  services.resolved.extraConfig = ''
    DNSStubListener=no
  '';
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;

    extraConfig = ''
      local=/gg23/
      domain=gg23
      expand-hosts
      listen-address=10.42.0.1
      interface=int0
    '';
  };

  environment.systemPackages = [
    (pkgs.writers.writeDashBin "restart_router" ''
      ${pkgs.mosquitto}/bin/mosquitto_pub -h localhost -t 'cmnd/router/POWER' -u gg23 -P gg23-mqtt -m OFF
      sleep 2
      ${pkgs.mosquitto}/bin/mosquitto_pub -h localhost -t 'cmnd/router/POWER' -u gg23 -P gg23-mqtt -m ON
    '')
  ];
}
