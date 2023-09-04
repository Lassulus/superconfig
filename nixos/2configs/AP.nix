{ config, pkgs, ... }:
let
  wifi = "wlp0s29u1u2";
in {
  boot.extraModulePackages = [
    pkgs.linuxPackages.rtl8814au
  ];
  networking.networkmanager.unmanaged = [ wifi "et0" ];

  systemd.services.hostapd = {
    description = "hostapd wireless AP";
    path = [ pkgs.hostapd ];
    wantedBy = [ "network.target" ];

    after = [ "${wifi}-cfg.service" "nat.service" "bind.service" "dhcpd.service" "sys-subsystem-net-devices-${wifi}.device" ];

    serviceConfig = {
      ExecStart = "${pkgs.hostapd}/bin/hostapd ${pkgs.writeText "hostapd.conf" ''
        interface=${wifi}
        hw_mode=a
        channel=36
        ieee80211d=1
        country_code=DE
        ieee80211n=1
        ieee80211ac=1
        wmm_enabled=1

        # 5ghz
        ssid=krebsing
        auth_algs=1
        wpa=2
        wpa_key_mgmt=WPA-PSK
        rsn_pairwise=CCMP
        wpa_passphrase=aidsballz
      ''}";
      Restart = "always";
    };
  };

  networking.bridges.br0.interfaces = [
    wifi
    "et0"
  ];

  networking.interfaces.br0.ipv4.addresses = [
    { address = "10.99.0.1"; prefixLength = 24; }
  ];
  services.dhcpd4 = {
    enable = true;
    interfaces = [ "br0" ];
    extraConfig = ''
      option subnet-mask 255.255.255.0;
      option routers 10.99.0.1;
      option domain-name-servers 1.1.1.1, 8.8.8.8;
      subnet 10.99.0.0 netmask 255.255.255.0 {
        range 10.99.0.100 10.99.0.200;
      }
    '';
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  krebs.iptables.tables.filter.FORWARD.rules = [
    { v6 = false; predicate = "-d 10.99.0.0/24 -o br0 -m conntrack --ctstate RELATED,ESTABLISHED"; target = "ACCEPT"; }
    { v6 = false; predicate = "-s 10.99.0.0/24 -i br0"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i br0 -o br0"; target = "ACCEPT"; }
    { v6 = false; predicate = "-i br0 -o br0"; target = "ACCEPT"; }
    { v6 = false; predicate = "-o br0"; target = "REJECT --reject-with icmp-port-unreachable"; }
    { v6 = false; predicate = "-i br0"; target = "REJECT --reject-with icmp-port-unreachable"; }
  ];
  krebs.iptables.tables.nat.PREROUTING.rules = mkBefore [
    { v6 = false; predicate = "-s 10.99.0.0/24"; target = "ACCEPT"; }
  ];
  krebs.iptables.tables.nat.POSTROUTING.rules = [
    #TODO find out what this is about?
    { v6 = false; predicate = "-s 10.99.0.0/24 -d 224.0.0.0/24"; target = "RETURN"; }
    { v6 = false; predicate = "-s 10.99.0.0/24 -d 255.255.255.255"; target = "RETURN"; }

    { v6 = false; predicate = "-s 10.99.0.0/24 ! -d 10.99.0.0/24"; target = "MASQUERADE"; }
    { v6 = false; predicate = "-s 10.99.0.0/24 ! -d 10.99.0.0/24 -p tcp"; target = "MASQUERADE --to-ports 1024-65535"; }
    { v6 = false; predicate = "-s 10.99.0.0/24 ! -d 10.99.0.0/24 -p udp"; target = "MASQUERADE --to-ports 1024-65535"; }
  ];
}
