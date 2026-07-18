{
  config,
  pkgs,
  ...
}:
let
  authDomain = "auth.lassul.us";
in
{
  # Shared forward-auth layer for services that lack a native OIDC client.
  # A single oauth2-proxy instance authenticates against pocket-id
  # (id.lassul.us). Gate any service behind pocket-id SSO with one line:
  #
  #   services.oauth2-proxy.nginx.virtualHosts."foo.lassul.us" = { };
  #
  # One OIDC client + cookie domain .lassul.us yield a single shared login
  # session across every *.lassul.us service (true single sign-on). Access is
  # uniform (any authenticated pocket-id user); services that need per-service
  # authorization should use their own pocket-id OIDC client directly instead.
  #
  # Register ONE OIDC client in pocket-id with redirect URL
  # https://auth.lassul.us/oauth2/callback, then run `clan vars generate` to
  # enter its client id/secret.
  clan.core.vars.generators.oauth2-proxy-secrets = {
    prompts.client_id = {
      description = "pocket-id OIDC client ID for oauth2-proxy (redirect URL https://${authDomain}/oauth2/callback)";
      type = "line";
      persist = true;
    };
    prompts.client_secret = {
      description = "pocket-id OIDC client secret for oauth2-proxy";
      type = "hidden";
      persist = true;
    };
  };
  clan.core.vars.generators.oauth2-proxy-env = {
    dependencies = [ "oauth2-proxy-secrets" ];
    files."oauth2.env" = { };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      cat > "$out/oauth2.env" << EOF
      OAUTH2_PROXY_CLIENT_ID=$(cat $in/oauth2-proxy-secrets/client_id)
      OAUTH2_PROXY_CLIENT_SECRET=$(cat $in/oauth2-proxy-secrets/client_secret)
      OAUTH2_PROXY_COOKIE_SECRET=$(openssl rand -base64 24 | tr -d '\n')
      EOF
    '';
  };

  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://id.lassul.us";
    keyFile = config.clan.core.vars.generators.oauth2-proxy-env.files."oauth2.env".path;
    email.domains = [ "*" ]; # any authenticated pocket-id user
    reverseProxy = true;
    trustedProxyIP = [
      "127.0.0.1/32"
      "::1/128"
    ];
    setXauthrequest = true;
    cookie.secure = true;
    cookie.domain = ".lassul.us";
    redirectURL = "https://${authDomain}/oauth2/callback";
    # pocket-id has no SMTP/email verification, so it emits email_verified=false;
    # oauth2-proxy would otherwise reject the login.
    extraConfig.whitelist-domain = ".lassul.us";
    extraConfig.insecure-oidc-allow-unverified-email = true;
  };

  # Central vhost hosting the /oauth2/* endpoints (locations added by the
  # oauth2-proxy nginx module); it only needs TLS here.
  services.oauth2-proxy.nginx.domain = authDomain;
  services.nginx.virtualHosts.${authDomain} = {
    enableACME = true;
    forceSSL = true;
  };
}
