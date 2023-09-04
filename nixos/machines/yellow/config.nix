{ config, lib, pkgs, ... }: let
  vpnPort = 1637;
  torrentport = 56709; # port forwarded in airvpn webinterface
in {
  imports = [
    <stockholm/lass>
    <stockholm/lass/2configs>
    <stockholm/lass/2configs/retiolum.nix>
    <stockholm/lass/2configs/services/flix>
  ];

  krebs.build.host = config.krebs.hosts.yellow;

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN737BAP36KiZO97mPKTIUGJUcr97ps8zjfFag6cUiYL";
  };

  networking.useHostResolvConf = false;
  networking.useNetworkd = true;

  networking.wg-quick.interfaces.airvpn.configFile = "/var/src/secrets/airvpn.conf";
  services.transmission.settings.peer-port = torrentport;

  # only allow traffic through openvpn
  krebs.iptables = {
    enable = true;
    tables.filter.INPUT.rules = [
      { predicate = "-i airvpn -p tcp --dport ${toString torrentport}"; target = "ACCEPT"; }
      { predicate = "-i airvpn -p udp --dport ${toString torrentport}"; target = "ACCEPT"; }
    ];
    tables.filter.OUTPUT = {
      policy = "DROP";
      rules = [
        { predicate = "-o lo"; target = "ACCEPT"; }
        { predicate = "-p udp --dport ${toString vpnPort}"; target = "ACCEPT"; }
        { predicate = "-o airvpn"; target = "ACCEPT"; }
        { predicate = "-o retiolum"; target = "ACCEPT"; }
        { v6 = false; predicate = "-d 1.1.1.1/32"; target = "ACCEPT"; }
        { v6 = false; predicate = "-d 1.0.0.1/32"; target = "ACCEPT"; }
        { v6 = false; predicate = "-o eth0 -d 10.233.2.0/24"; target = "ACCEPT"; }
      ];
    };
  };
}
