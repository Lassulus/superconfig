{ config, pkgs, ... }: let
  torrentport = 56709; # port forwarded in airvpn webinterface
in {
  imports = [
    ../../.
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/services/flix
  ];

  services.transmission.settings.peer-port = torrentport;
  krebs.build.host = config.krebs.hosts.yellow;

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN737BAP36KiZO97mPKTIUGJUcr97ps8zjfFag6cUiYL";
  };

  networking.useHostResolvConf = false;
  networking.useNetworkd = true;

  systemd.services.transmission-netns = {
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.iproute2
      pkgs.wireguard-tools
    ];
    script = ''
      set -efux
      ip netns delete transmission || :
      ip netns add transmission
      ip -n transmission link set lo up
      ip link add airvpn type wireguard
      ip link set airvpn netns transmission
      ip -n transmission addr add 10.176.43.231/32 dev airvpn
      ip -n transmission addr add fd7d:76ee:e68f:a993:41b3:846b:d271:30d8/128 dev airvpn
      ip netns exec transmission wg syncconf airvpn <(wg-quick strip /etc/secrets/airvpn.conf)
      ip -n transmission link set airvpn up
      ip -n transmission route add default dev airvpn
      ip link add t1 type veth peer name t2
      ip link set t1 netns transmission
      ip addr add 128.0.0.2/30 dev t2
      ip link set t2 up
      ip -n transmission addr add 128.0.0.1/30 dev t1
      ip -n transmission link set t1 up
    '';
    serviceConfig = {
      RemainAfterExit = true;
      Type = "oneshot";
    };
  };

  systemd.services.transmission = {
    after = [ "transmission-netns.service" ];
    serviceConfig.NetworkNamespacePath = "/var/run/netns/transmission";
  };
}
