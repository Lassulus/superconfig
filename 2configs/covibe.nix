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
let
  # Patched omp: env-driven headless collab autostart, plus a self-hosted
  # collab-web SPA (base path /c/, external analytics stripped) installed to
  # share/collab-web so covibe can serve the browser client itself — nothing
  # loads from my.omp.sh.
  ompPatched = (self.legacyPackages.${pkgs.stdenv.hostPlatform.system}.llm.omp).overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [ ./omp-collab-autostart.patch ];
    postBuild = (o.postBuild or "") + ''
      echo "Building self-hosted collab-web (base /c/)..."
      sed -i '/um\.can\.ac/d' packages/collab-web/index.html
      (
        cd packages/collab-web
        bun build ./index.html --outdir dist --minify \
          --entry-naming '[hash].[ext]' --chunk-naming '[hash].[ext]' --asset-naming '[hash].[ext]' \
          --public-path /c/
        mv dist/*.html dist/index.html
        cp -R public/. dist/
      )
    '';
    postInstall = (o.postInstall or "") + ''
      mkdir -p $out/share
      cp -R packages/collab-web/dist $out/share/collab-web
    '';
  });
in
{
  # covibe: co-vibing dashboard. Launches omp sessions in zellij as the
  # pairprogramming user, shows live sessions + collab QR codes, and exposes a
  # REST API. Browser auth via the local pocket-id IdP (id.lassul.us); the REST
  # surface additionally accepts a generated API key. Collab uses omp's native
  # stack against a self-hosted relay + self-hosted collab-web (no my.omp.sh).
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
    ompPackage = ompPatched;
    webRoot = "${ompPatched}/share/collab-web";
    relayHost = domain;
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
    # Collab relay websockets (/r/<roomId>) are long-lived and idle between
    # turns; neither the relay nor omp send keepalive pings, so nginx's default
    # 60s proxy_read_timeout would sever idle sessions and trigger omp's
    # "connection lost, reconnecting" loop. Give the relay a long idle window.
    locations."/r/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
      '';
    };
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}
