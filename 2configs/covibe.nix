let
  domain = "covibe.lassul.us";
  port = 8770;
in
{
  config,
  pkgs,
  self,
  ...
}:
{
  # covibe: co-vibing dashboard. Launches omp sessions in zellij as the
  # pairprogramming user, shows live sessions + collab QR codes, and exposes a
  # REST API. Browser auth via the local pocket-id IdP (id.lassul.us); the REST
  # surface additionally accepts a generated API key.
  imports = [ self.inputs.covibe.nixosModules.default ];

  # Cookie-signing secret + REST API key (generated), plus the pocket-id client
  # secret (prompted once), materialised into one EnvironmentFile:
  # COVIBE_COOKIE_SECRET, COVIBE_API_KEYS, COVIBE_OIDC_CLIENT_SECRET.
  clan.core.vars.generators.covibe = {
    files."env" = { };
    files."api_key" = { }; # readable copy of the key for clients
    prompts.oidc_client_secret = {
      description = "pocket-id OIDC client secret for covibe";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      ck=$(openssl rand -hex 32)
      ak=$(openssl rand -hex 32)
      cs=$(cat "$prompts"/oidc_client_secret)
      printf '%s' "$ak" > "$out/api_key"
      printf 'COVIBE_COOKIE_SECRET=%s\nCOVIBE_API_KEYS=%s\nCOVIBE_OIDC_CLIENT_SECRET=%s\n' \
        "$ck" "$ak" "$cs" > "$out/env"
    '';
  };

  services.covibe = {
    enable = true;
    user = "pairprogramming";
    ompPackage = self.legacyPackages.${pkgs.stdenv.hostPlatform.system}.llm.omp;
    webUrl = "https://${domain}";
    dashboard = {
      addr = "127.0.0.1:${toString port}";
      workspaceRoot = "/home/pairprogramming/covibe";
      environmentFile = config.clan.core.vars.generators.covibe.files."env".path;
      oidc = {
        issuer = "https://id.lassul.us";
        clientId = "a7e4b0aa-f09d-472a-965b-908cd4634f16";
        redirectUrl = "https://${domain}/auth/callback";
      };
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
