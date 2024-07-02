{ self, lib, config, ... }:
{
  imports = [
    self.inputs.clan-core.clanModules.postgresql
  ];
  clan.postgresql.users.hedgedoc = {};
  clan.postgresql.databases.hedgedoc = {};
  options.clan.hedgedoc = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain of the hedgedoc instance.";
    };
  };
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
      # db = {
      #   dialect = "sqlite";
      #   storage = "/var/lib/hedgedoc/db.hedgedoc.sqlite";
      # };
      useCDN = false;
      port = 3091;
      domain = config.hedgedoc.domain;
      allowFreeURL = true;
      defaultPermission = "freely";

      useSSL = true;
      protocolUseSSL = true;
      sslCAPath = [ "/etc/ssl/certs/ca-certificates.crt" ];
      sslCertPath = "/var/lib/acme/${config.clan.hedgedoc.domain}/cert.pem";
      sslKeyPath = "/var/lib/acme/${config.clan.hedgedoc.domain}/key.pem";
      dhParamPath = config.security.dhparams.params.hedgedoc.path;
    };

    # https://github.com/settings/applications/2352617
    environmentFile = config.clanCore.facts.secretUploadDirectory + "/hedgedoc.env";
  };

  clanCore.facts.services.hedgedoc-github-auth = {
    secret."hedgedoc.env" = { };
    generator.script = ''
      cat > "$secrets"/hedgedoc.env
    '';
    generator.prompt = ''
      goto https://github.com/settings/ap:qplications/2352617 and paste the data in the following format:
      GITHUB_CLIENT_ID=...
      GITHUB_CLIENT_SECRET=...
    '';
  };
}
