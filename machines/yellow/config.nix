{ config, pkgs, lib, ... }: let
  torrentport = 56709; # port forwarded in airvpn webinterface
in {
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/services/flix
  ];

  services.transmission.settings.peer-port = torrentport;
  krebs.build.host = config.krebs.hosts.yellow;

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = builtins.readFile ./facts/yellow.sync.pub;
  };

  networking.useHostResolvConf = false;
  networking.useNetworkd = true;
  # we need to set a namserver here that can be also be reached from the transmission network namespace
  environment.etc."resolv.conf".text = ''
    options edns0
    nameserver 9.9.9.9
  '';
  services.resolved.enable = lib.mkForce false;

  systemd.services.transmission-netns = {
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.iproute2
      pkgs.wireguard-tools
    ];
    script = ''
      set -efux
      ip netns delete transmission || :
      ip link del t2 || :
      ip netns add transmission
      ip -n transmission link set lo up
      ip link add airvpn type wireguard
      ip link set airvpn netns transmission
      ip -n transmission addr add 10.176.43.231/32 dev airvpn
      ip -n transmission addr add fd7d:76ee:e68f:a993:41b3:846b:d271:30d8/128 dev airvpn
      ip netns exec transmission wg syncconf airvpn <(wg-quick strip /etc/secrets/airvpn.conf)
      ip -n transmission link set airvpn up
      ip -n transmission route add default dev airvpn
      ip -6 -n transmission route add default dev airvpn
      ip link add t1 type veth peer name t2
      ip link set t1 netns transmission

      ip addr add 128.0.0.2/30 dev t2
      ip addr add fdb4:3310:947::1/64 dev t2
      ip link set t2 up
      ip -n transmission addr add 128.0.0.1/30 dev t1
      ip -n transmission addr add fdb4:3310:947::2/64 dev t1
      ip -n transmission link set t1 up
      ip -n transmission route add 42:0:ce16::3110/16 via fdb4:3310:947::1 dev t1
    '';
    serviceConfig = {
      RemainAfterExit = true;
      Type = "oneshot";
    };
  };

  # so we can forward traffic from the transmission network namespace
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  systemd.services.transmission = {
    after = [ "transmission-netns.service" ];
    serviceConfig = {
      NetworkNamespacePath = "/var/run/netns/transmission";
      # https://github.com/NixOS/nixpkgs/issues/258793
      RootDirectoryStartOnly = lib.mkForce false;
      RootDirectory = lib.mkForce "";
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
    };
  };
  clanCore.secrets.yellow-container = {
    secrets."yellow.sync.key" = { };
    facts."yellow.sync.pub" = { };
    generator.path = with pkgs; [ coreutils openssh ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/yellow.sync.key
      mv "$secrets"/yellow.sync.key "$facts"/yellow.sync.pub
    '';
  };
}
