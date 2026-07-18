let
  domain = "id.lassul.us";
  port = 1411;
in
{
  config,
  pkgs,
  ...
}:
{
  # Pocket ID: passkey-based OIDC provider. Serves as the SSO IdP for other
  # services on this host (e.g. the SilverBullet editing instance via
  # oauth2-proxy). First-run bootstrap (admin user + OIDC client registration)
  # happens through its web UI at https://id.lassul.us.

  # v2 requires ENCRYPTION_KEY (>=16 bytes) to encrypt keys at rest.
  clan.core.vars.generators.pocket-id = {
    files."encryption_key" = { };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      openssl rand -hex 32 | tr -d '\n' > "$out/encryption_key"
    '';
  };

  services.pocket-id = {
    enable = true;
    credentials.ENCRYPTION_KEY = config.clan.core.vars.generators.pocket-id.files."encryption_key".path;
    settings = {
      APP_URL = "https://${domain}";
      TRUST_PROXY = true;
      ANALYTICS_DISABLED = true;
      HOST = "127.0.0.1";
      PORT = port;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}
