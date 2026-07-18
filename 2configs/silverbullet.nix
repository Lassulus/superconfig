{
  config,
  lib,
  ...
}:
let
  publicDomain = "wiki.lassul.us";
  adminDomain = "wiki-rw.lassul.us";
  spaceDir = "/var/lib/silverbullet";
  publicPort = 3000;
  adminPort = 3001;
  user = "silverbullet";
  group = "silverbullet";
in
{
  # SilverBullet auth is all-or-nothing per instance and has no OIDC client, so
  # we run two instances over the same space:
  #   - public (wiki.lassul.us):    anonymous, SB_READ_ONLY
  #   - admin  (wiki-rw.lassul.us): read-write, no built-in auth; gated by the
  #                                 shared oauth2-proxy -> pocket-id SSO
  #                                 (see 2configs/oauth2-proxy.nix).

  # --- Public, anonymous, read-only instance (nixpkgs module) -------------
  services.silverbullet = {
    enable = true;
    inherit user group;
    listenAddress = "127.0.0.1";
    listenPort = publicPort;
    spaceDir = spaceDir;
  };
  systemd.services.silverbullet.environment = {
    SB_READ_ONLY = "1";
    SB_SHELL_BACKEND = "off";
  };

  # --- Admin, read-write instance (no built-in auth; SSO in front) --------
  systemd.services.silverbullet-admin = {
    description = "SilverBullet (admin, read-write)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      SB_SHELL_BACKEND = "off";
      # Forward-auth (oauth2-proxy) and SilverBullet's PWA service worker fight
      # over redirects/caching; disabling the service worker sends every request
      # straight to the server so auth behaves predictably.
      SB_DISABLE_SERVICE_WORKER = "1";
    };
    serviceConfig = {
      Type = "simple";
      User = user;
      Group = group;
      StateDirectory = "silverbullet";
      ExecStart = "${lib.getExe config.services.silverbullet.package} --port ${toString adminPort} --hostname 127.0.0.1 '${spaceDir}'";
      Restart = "on-failure";
    };
  };

  # Gate the read-write instance behind the shared pocket-id SSO layer.
  services.oauth2-proxy.nginx.virtualHosts.${adminDomain} = { };

  # --- nginx vhosts -------------------------------------------------------
  services.nginx.virtualHosts.${publicDomain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString publicPort}";
      proxyWebsockets = true;
    };
  };
  # The oauth2-proxy nginx module merges auth_request + /oauth2/ endpoints into
  # this vhost; we only add ACME/TLS and the backend proxy to the admin app.
  services.nginx.virtualHosts.${adminDomain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString adminPort}";
      proxyWebsockets = true;
    };
  };
}
