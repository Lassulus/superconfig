{ config, ... }:
{
  services.matrix-synapse = {
    enable = true;
    settings = {
      server_name = "lassul.us";
      # registration_shared_secret = "yolo";
      database = {
        args.user = "matrix-synapse";
        args.database = "matrix-synapse";
        name = "psycopg2";
      };
      turn_uris  = [
        "turn:turn.matrix.org?transport=udp"
        "turn:turn.matrix.org?transport=tcp"
      ];
      listeners = [
        {
          port = 8008;
          bind_addresses = [
            "::1"
            config.krebs.build.host.nets.retiolum.ip6.addr
          ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" ];
              compress = true;
            }
            {
              names = [ "federation" ];
              compress = false;
            }
          ];
        }
      ];
    };
  };

  # TODO add other VPNs here as well
  networking.firewall.interfaces.retiolum.allowedTCPPorts = [ 8008 ];

  services.postgresql.enable = true;
  services.postgresql = {
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };
}
