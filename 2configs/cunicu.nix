{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.cunicu
  ];

  networking.firewall.allowedUDPPorts = [ 42230 ];

  environment.etc."cunicu.yaml".text = builtins.toJSON {
    # backends = [
    #   "grpc://signal.cunicu.li:443"
    # ];
    rpc.socket = "/var/run/cunicu.sock";

    listen_port = 51820;

    sync_routes = true;
    sync_hosts = true;

    domain = "c";

    discover_peers = true;
    discover_endpoints = true;
    community = "aidsballs";

    networks = [
      "10.245.0.0/16"
    ];

    ice = {
      urls = [
        "stun:stun3.l.google.com:19302"
        "stun:relay.webwormhole.io"
        "stun:stun.sipgate.net"
        "stun:stun.ekiga.net"
        "stun:stun.services.mozilla.com"
      ];
      interface_filter = "w*|e*|v*|i*";
    };

    interfaces.wiregrill = { };

    peers = lib.mapAttrs (
      _: host:
      {
        public_key = host.nets.wiregrill.wireguard.pubkey;
        allowed_ips =
          with host.nets.wiregrill;
          [
            "${ip6.addr}/128"
          ]
          ++ (lib.optional (ip4 != null) "${ip4.addr}/32");
      }
      // lib.optionalAttrs (host.nets.wiregrill.via != null) {
        endpoint = host.nets.wiregrill.via.ip4.addr + ":${toString host.nets.wiregrill.wireguard.port}";
      }
    ) (lib.filterAttrs (_: host: lib.hasAttr "wiregrill" host.nets) config.krebs.hosts);
  };

  systemd.services.cunicu = {
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.environment.etc."cunicu.yaml".source ];
    environment = {
      CUNICU_CONFIG_ALLOW_INSECURE = "true";
      CUNICU_EXPERIMENTAL = "true";
    };
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "cunicu" ''
        ${pkgs.cunicu}/bin/cunicu daemon
      '';
    };
  };
}
