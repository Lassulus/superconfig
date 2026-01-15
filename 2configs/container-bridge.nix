{ config, pkgs, ... }:
{
  # Local DNS64 resolver for containers
  # Synthesizes AAAA records with 64:ff9b::/96 prefix for IPv4-only hosts
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [
          "fd00:c700::1"
          "127.0.0.1"
        ];
        access-control = [
          "fd00:c700::/64 allow"
          "127.0.0.0/8 allow"
        ];
        # DNS64: synthesize AAAA with NAT64 prefix
        module-config = ''"dns64 validator iterator"'';
        dns64-prefix = "64:ff9b::/96";
        # Always synthesize, even if real AAAA exists (needed when host has no IPv6)
        dns64-synthall = "yes";
        # Handle reverse DNS for NAT64 prefix locally (return NXDOMAIN immediately)
        # Without this, PTR lookups for 64:ff9b::* timeout waiting for upstream
        local-zone = ''"0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.b.9.f.f.4.6.0.0.ip6.arpa." static'';
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "1.1.1.1" # Cloudflare (IPv4 - always works)
            "8.8.8.8" # Google (IPv4)
            "2606:4700:4700::1111" # Cloudflare (IPv6 - when available)
          ];
        }
      ];
    };
  };

  # Bridge interface for containers
  systemd.network.netdevs."10-ctr0" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "ctr0";
    };
  };

  systemd.network.networks."10-ctr0" = {
    matchConfig.Name = "ctr0";
    address = [ "fd00:c700::1/64" ];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6SendRA = true; # Enable Router Advertisements
    };

    # Router Advertisement configuration
    ipv6SendRAConfig = {
      Managed = false; # No DHCPv6 for addresses (use SLAAC)
      OtherInformation = false; # No DHCPv6 for DNS (use RDNSS)
      RouterLifetimeSec = 1800;
      DNS = [ "fd00:c700::1" ]; # RDNSS: advertise DNS64 resolver
    };
    ipv6Prefixes = [
      { Prefix = "fd00:c700::/64"; }
    ];
    # Advertise NAT64 prefix via PREF64 option (RFC 8781)
    ipv6PREF64Prefixes = [
      { Prefix = "64:ff9b::/96"; }
    ];
  };

  # Exclude from NetworkManager
  networking.networkmanager.unmanaged = [ "ctr0" ];

  # IP forwarding
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

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

  # Update Jool pool4 with current IPv4 address (needed for NAT64 on dynamic IPs)
  systemd.services.jool-pool4-update = {
    description = "Update Jool NAT64 pool4 with current IPv4";
    after = [
      "jool.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.iproute2
      pkgs.gawk
      pkgs.jool-cli
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Get default route's source IP
      IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7}')
      if [ -n "$IP" ]; then
        # Flush old pool and add new
        jool pool4 flush --tcp 2>/dev/null || true
        jool pool4 flush --udp 2>/dev/null || true
        jool pool4 flush --icmp 2>/dev/null || true
        jool pool4 add "$IP" 1-65535 --tcp
        jool pool4 add "$IP" 1-65535 --udp
        jool pool4 add "$IP" 1-65535 --icmp
        echo "Jool pool4 updated to $IP"
      else
        echo "No IPv4 address found, skipping pool4 update"
      fi
    '';
  };

  # Firewall rules for container bridge
  krebs.iptables.tables.filter.FORWARD.rules = [
    # IPv6 forwarding for containers
    {
      v4 = false;
      v6 = true;
      predicate = "-i ctr0";
      target = "ACCEPT";
    }
    {
      v4 = false;
      v6 = true;
      predicate = "-o ctr0 -m conntrack --ctstate RELATED,ESTABLISHED";
      target = "ACCEPT";
    }
    # IPv4 forwarding for NAT64 translated packets
    {
      v4 = true;
      v6 = false;
      predicate = "-m conntrack --ctstate RELATED,ESTABLISHED";
      target = "ACCEPT";
    }
    {
      v4 = true;
      v6 = false;
      predicate = "";
      target = "ACCEPT";
    }
  ];

  # NAT66 - masquerade container IPv6 to reach public IPv6 (when host has IPv6)
  # NAT44 - masquerade NAT64 translated IPv4 packets (exclude localhost!)
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    {
      v4 = false;
      v6 = true;
      predicate = "-s fd00:c700::/64 ! -d fd00:c700::/64";
      target = "MASQUERADE";
    }
    {
      v4 = true;
      v6 = false;
      predicate = "! -d 127.0.0.0/8 ! -o lo";
      target = "MASQUERADE";
    } # Don't masquerade localhost
  ];

  # Allow containers to reach host's DNS64 resolver (IPv6 only)
  krebs.iptables.tables.filter.INPUT.rules = [
    {
      v4 = false;
      v6 = true;
      predicate = "-s fd00:c700::/64 -p udp --dport 53";
      target = "ACCEPT";
    }
    {
      v4 = false;
      v6 = true;
      predicate = "-s fd00:c700::/64 -p tcp --dport 53";
      target = "ACCEPT";
    }
  ];
}
