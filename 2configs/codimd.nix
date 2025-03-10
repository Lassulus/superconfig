{ ... }:
let
  domain = "pad.lassul.us";
in
{

  # redirect legacy domain to new one
  # services.nginx.virtualHosts."codi.lassul.us" = {
  #   enableACME = true;
  #   addSSL = true;
  #   locations."/".return = "301 https://${domain}\$request_uri";
  # };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    acmeFallbackHost = "neoprism.lassul.us";
    locations."/" = {
      # proxyPass = "https://localhost:3091";
      proxyPass = "https://neoprism.lassul.us";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };

  # security.acme.certs.${domain}.group = "hedgecert";
  # users.groups.hedgecert.members = [
  #   "hedgedoc"
  #   "nginx"
  # ];

  # security.dhparams = {
  #   enable = true;
  #   params.hedgedoc = { };
  # };

  # services.borgbackup.jobs.hetzner.paths = [
  #   "/var/backup"
  #   "/var/lib/hedgedoc"
  # ];
  # systemd.services.hedgedoc-backup = {
  #   startAt = "daily";
  #   serviceConfig = {
  #     ExecStart = pkgs.writers.writeDash "pad-backup" ''
  #       until ${pkgs.sqlite}/bin/sqlite3 /var/lib/hedgedoc/db.hedgedoc.sqlite ".backup /var/backup/hedgedoc/backup.sq3"; do
  #         sleep 1
  #       done
  #     '';
  #     Type = "oneshot";
  #   };
  # };

  # systemd.services.hedgedoc.environment = {
  #   CMD_COOKIE_POLICY = "none";
  #   CMD_CSP_ALLOW_FRAMING = "true";
  # };

  # services.hedgedoc = {
  #   enable = true;
  #   settings = {
  #     allowOrigin = [ domain ];
  #     db = {
  #       dialect = "sqlite";
  #       storage = "/var/lib/hedgedoc/db.hedgedoc.sqlite";
  #     };
  #     useCDN = false;
  #     port = 3091;
  #     domain = domain;
  #     allowFreeURL = true;
  #     defaultPermission = "freely";

  #     useSSL = true;
  #     protocolUseSSL = true;
  #     sslCAPath = [ "/etc/ssl/certs/ca-certificates.crt" ];
  #     sslCertPath = "/var/lib/acme/${domain}/cert.pem";
  #     sslKeyPath = "/var/lib/acme/${domain}/key.pem";
  #     dhParamPath = config.security.dhparams.params.hedgedoc.path;
  #   };

  #   # https://github.com/settings/applications/2352617
  #   environmentFile = config.clanCore.facts.secretUploadDirectory + "/hedgedoc.env";
  # };

  # clanCore.facts.services.hedgedoc-github-auth = {
  #   secret."hedgedoc.env" = { };
  #   generator.script = ''
  #     echo "$prompt_value" > "$secrets"/hedgedoc.env
  #   '';
  #   generator.prompt = ''
  #     goto https://github.com/settings/applications/2352617 and paste the data in the following format:
  #     GITHUB_CLIENT_ID=...
  #     GITHUB_CLIENT_SECRET=...
  #   '';
  # };
}
