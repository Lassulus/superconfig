{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.clan.hedgedoc = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain of the hedgedoc instance.";
    };
  };
  config = {

    security.acme.certs.${config.clan.hedgedoc.domain}.group = "hedgecert";
    users.groups.hedgecert.members = [
      "hedgedoc"
      "nginx"
    ];

    security.dhparams = {
      enable = true;
      params.hedgedoc = { };
    };

    services.hedgedoc = {
      enable = true;
      settings = {
        allowOrigin = [
          "localhost"
          config.clan.hedgedoc.domain
        ];
        useCDN = true;
        port = 3091;
        domain = config.clan.hedgedoc.domain;
        allowFreeURL = true;
        defaultPermission = "freely";
        # debug = true;
        # useSSL = true;
        # hsts.enable = false;
        # protocolUseSSL = true;

        useSSL = true;
        protocolUseSSL = true;
        sslCAPath = [ "/etc/ssl/certs/ca-certificates.crt" ];
        sslCertPath = "/var/lib/acme/${config.clan.hedgedoc.domain}/cert.pem";
        sslKeyPath = "/var/lib/acme/${config.clan.hedgedoc.domain}/key.pem";
        dhParamPath = config.security.dhparams.params.hedgedoc.path;
      };
    };

    systemd.services.hedgedoc.serviceConfig.SystemCallFilter = [
      "fchown"
    ];

    systemd.services.hedgedoc.serviceConfig.EnvironmentFile = [
      config.clan.core.vars.generators.hedgedoc.files."hedgedoc.env".path
    ];
    clan.core.vars.generators.hedgedoc = {
      files."hedgedoc.env" = { };
      runtimeInputs = [ pkgs.pwgen ];
      script = ''
        pwgen -s 64 1 > session_secret
        cat >>  "$out/hedgedoc.env" <<EOF
        CMD_SESSION_SECRET=$(cat session_secret)
        EOF
      '';
    };

    services.nginx.virtualHosts.${config.clan.hedgedoc.domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        # proxyPass = "https://localhost:3091";
        proxyPass = "https://localhost:${toString config.services.hedgedoc.settings.port}";
        recommendedProxySettings = true;
        # proxyWebsockets = true;
      };
      locations."/socket.io/" = {
        # proxyPass = "https://localhost:3091";
        proxyPass = "https://localhost:${toString config.services.hedgedoc.settings.port}";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };

  };
}
