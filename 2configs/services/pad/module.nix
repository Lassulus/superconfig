{
  self,
  lib,
  config,
  ...
}:
{
  imports = [
    self.inputs.clan-core.clanModules.postgresql
  ];
  options.clan.hedgedoc = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain of the hedgedoc instance.";
    };
  };
  config = {
    clan.postgresql.users.hedgedoc = { };
    clan.postgresql.databases.hedgedoc.create.options.OWNER = "matrix-synapse";
    systemd.services.hedgedoc.environment = {
      CMD_COOKIE_POLICY = "none";
      CMD_CSP_ALLOW_FRAMING = "true";
    };

    services.hedgedoc = {
      enable = true;
      settings = {
        allowOrigin = [ config.clan.hedgedoc.domain ];
        db = {
          dialect = "postgres";
          host = "/run/postgresql";
          database = "hedgedoc";
          username = "hedgedoc";
        };
        useCDN = false;
        port = 3091;
        domain = config.clan.hedgedoc.domain;
        allowFreeURL = true;
        defaultPermission = "freely";
        useSSL = false;
        debug = true;
      };
    };

    services.nginx.virtualHosts.${config.clan.hedgedoc.domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.hedgedoc.settings.port}";
        proxyWebsockets = true;
      };
    };

  };
}
