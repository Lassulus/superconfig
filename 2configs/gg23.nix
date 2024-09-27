{ lib, pkgs, ... }:
{
  # vodafone router drifts out of time
  services.timesyncd.servers = [
    "0.pool.ntp.org"
    "1.pool.ntp.org"
    "2.pool.ntp.org"
    "3.pool.ntp.org"
  ];
  systemd.network.networks."50-et0" = {
    matchConfig.Name = "et0";
    DHCP = "yes";
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
        # printer
        dhcpServerStaticLeaseConfig = {
          Address = "10.42.0.4";
          MACAddress = "3c:2a:f4:22:28:37";
        };
      }
      {
        # firetv
        dhcpServerStaticLeaseConfig = {
          Address = "10.42.0.11";
          MACAddress = "84:28:59:f0:d2:a8";
        };
      }
      # {
      #   dhcpServerStaticLeaseConfig = {
      #     Address = "10.42.0.10";
      #     MACAddress = "ea:4d:12:94:74:2a";
      #   };
      # }
      {
        dhcpServerStaticLeaseConfig = {
          Address = "10.42.0.10";
          MACAddress = "fe:fe:fe:fe:fe:fe";
        };
      }
    ];
  };
  networking.networkmanager.unmanaged = [ "int0" ];
  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i int0";
      target = "ACCEPT";
    }
  ];
  krebs.iptables.tables.filter.FORWARD.rules = [
    {
      predicate = "-i int0";
      target = "ACCEPT";
    }
    {
      predicate = "-o int0";
      target = "ACCEPT";
    }
    {
      predicate = "-p ipv6-icmp";
      target = "ACCEPT";
      v4 = false;
    }
  ];
  krebs.iptables.tables.nat.PREROUTING.rules = lib.mkBefore [
    {
      v6 = false;
      predicate = "-s 10.42.0.0/24";
      target = "ACCEPT";
    }
  ];
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    {
      v6 = false;
      predicate = "-s 10.42.0.0/24";
      target = "MASQUERADE";
    }
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
      listen-address=10.42.0.1,10.233.0.1
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
