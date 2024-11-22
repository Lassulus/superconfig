{
  lib,
  config,
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
        useCDN = false;
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

    services.nginx.virtualHosts.${config.clan.hedgedoc.domain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "https://localhost:3091";
        # proxyPass = "http://localhost:${toString config.services.hedgedoc.settings.port}";
        proxyWebsockets = true;
      };
    };

  };
}
