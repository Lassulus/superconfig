{ config, pkgs, ... }:
{
  services.matrix-synapse = {
    enable = true;
    settings = {
      server_name = "lassul.us";
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
    extraConfigFiles = [
      "/var/lib/matrix-synapse/registration_shared_secret.yaml"
    ];
  };
  systemd.services.matrix-synapse.serviceConfig.ExecStartPre = [
    "+${pkgs.writeScript "copy_registration_shared_secret" ''
      #!/bin/sh
      cp ${config.clanCore.facts.services.matrix-synapse.secret.synapse-registration_shared_secret.path} /var/lib/matrix-synapse/registration_shared_secret.yaml
      chown matrix-synapse:matrix-synapse /var/lib/matrix-synapse/registration_shared_secret.yaml
      chmod 600 /var/lib/matrix-synapse/registration_shared_secret.yaml
    ''}"
  ];

  clanCore.facts.services."matrix-synapse" = {
    secret."synapse-registration_shared_secret" = { };
    generator.path = with pkgs; [ coreutils pwgen ];
    generator.script = ''
      echo "registration_shared_secret: $(pwgen -s 32 1)" > "$secrets"/synapse-registration_shared_secret
    '';
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
