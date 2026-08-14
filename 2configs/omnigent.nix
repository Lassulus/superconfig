let
  domain = "omni.lassul.us";
  port = 8771;
  stateDir = "/var/lib/omnigent";
in
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  # Server-side agent catalog entry so a browser session can pick omp without
  # any per-user config: the generic ACP harness drives `omp acp` (omp speaks
  # the Agent Client Protocol natively). The command is unqualified on purpose
  # — it is resolved on the *host* that runs the session, not here.
  ompAgentConfig = pkgs.writeText "omp-config.yaml" ''
    spec_version: 1
    name: omp
    description: Oh My Pi (omp) over ACP — runs on whichever machine hosts the session.
    prompt: You are omp (Oh My Pi), a concise coding assistant.

    executor:
      type: omnigent
      config:
        harness: acp
        acp_agent:
          name: Oh My Pi
          command: omp acp
          # See tools/covibe/flake-module.nix: omp fails session/new outright
          # when omnigent's MCP relay cannot start, and the relay's
          # `python -I -m omnigent…` child cannot import omnigent under a
          # nixpkgs-wrapped interpreter.
          omnigent_mcp: false

    os_env:
      type: caller_process
      cwd: "."
      sandbox:
        type: none
  '';

  # `--agent` takes a bundle *directory* holding config.yaml.
  ompAgent = pkgs.runCommand "omnigent-agent-omp" { } ''
    mkdir -p $out
    cp ${ompAgentConfig} $out/config.yaml
  '';

  # One identity per line. Admins bypass every per-session ACL, which is what
  # makes sharing manageable at all: a session's creator gets LEVEL_OWNER, and
  # only owners/managers can grant others read (watch + diffs) or edit (steer).
  admins = pkgs.writeText "omnigent-admins" ''
    lass@lassul.us
  '';
in
{
  # omnigent: self-hosted agent meta-harness. The server owns sessions,
  # transcripts, per-session ACLs (read / edit / manage / owner), the per-file
  # diff view and the browser UI; the agents themselves run on whichever
  # machine registers as a *host*, so no coding agent runs on neoprism unless
  # someone points a host at it. `s covibe` in a project directory is the
  # client: it runs omp locally and registers the session here.
  #
  # Browser auth is the local pocket-id IdP. pocket-id has no declarative
  # client API, so register the client by hand at https://id.lassul.us:
  #   name:         omnigent
  #   callback URL: https://omni.lassul.us/auth/callback
  #   logout URL:   https://omni.lassul.us/
  # then paste its id + secret into the clan prompt below.

  # Generated cookie-signing secret plus the prompted pocket-id client
  # id/secret, materialised into one EnvironmentFile.
  clan.core.vars.generators.omnigent = {
    files."env" = { };
    prompts.oidc_client = {
      description = ''
        Register an OIDC client in pocket-id (https://id.lassul.us):
          name:         omnigent
          callback URL: https://omni.lassul.us/auth/callback
        Generate a client secret, then paste both lines:
          OMNIGENT_OIDC_CLIENT_ID=...
          OMNIGENT_OIDC_CLIENT_SECRET=...
      '';
      type = "multiline";
      persist = true;
    };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      {
        printf 'OMNIGENT_OIDC_COOKIE_SECRET=%s\n' "$(openssl rand -hex 32)"
        cat "$prompts"/oidc_client
      } > "$out/env"
    '';
  };

  systemd.services.omnigent = {
    description = "omnigent agent meta-harness (${domain})";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "nginx.service"
    ];
    wants = [ "network-online.target" ];
    environment = {
      HOME = stateDir;
      OMNIGENT_AUTH_ENABLED = "1";
      OMNIGENT_AUTH_PROVIDER = "oidc";
      OMNIGENT_OIDC_ISSUER = "https://id.lassul.us";
      OMNIGENT_OIDC_REDIRECT_URI = "https://${domain}/auth/callback";
      OMNIGENT_OIDC_LOGOUT_REDIRECT_URI = "https://${domain}/";
      OMNIGENT_OIDC_ALLOWED_DOMAINS = "lassul.us";
      # pocket-id emits `email` *and* `email_verified` in the id_token when the
      # `email` scope is requested (which omnigent does), but the value of
      # `email_verified` is the users.email_verified column, whose default comes
      # from the app-config key `emailsVerified` — shipped as false. omnigent
      # otherwise hard-rejects the login with "Could not determine user email
      # from IdP". The gate exists for IdPs where a user can self-assert an
      # arbitrary address; here users are provisioned by hand in pocket-id
      # (signups are disabled) and the domain allowlist above still applies, so
      # the marker carries no information for us.
      OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION = "1";
      # Default is 8 hours, which expires the `s covibe` session JWT roughly
      # once a working day and forces a browser round-trip through pocket-id.
      # A week is the pragmatic setting for a single-operator host behind an
      # invite-less IdP; the tokens live 0600 in ~/.omnigent/auth_tokens.json,
      # so shorten this if a laptop ever leaves the house untrusted.
      OMNIGENT_OIDC_SESSION_TTL_HOURS = "168";
      OMNIGENT_ADMIN_LIST_PATH = "${admins}";
      # The wheel checks PyPI for updates on every start otherwise.
      OMNIGENT_NO_UPDATE_CHECK = "1";
      # Off by default upstream; be explicit, it phones home otherwise.
      OMNIGENT_TELEMETRY_ENABLED = "0";
    };
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe self.packages.${pkgs.system}.omnigent)
        "server"
        "--host 127.0.0.1"
        "--port ${toString port}"
        "--no-open"
        "--database-uri sqlite:///${stateDir}/chat.db"
        "--artifact-location ${stateDir}/artifacts"
        "--agent ${ompAgent}"
      ];
      EnvironmentFile = [ config.clan.core.vars.generators.omnigent.files."env".path ];
      Restart = "always";
      RestartSec = 5;
      DynamicUser = true;
      StateDirectory = "omnigent";
      WorkingDirectory = stateDir;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # The session event stream is SSE (omnigent sets X-Accel-Buffering: no,
      # which nginx honours) and the terminal/host/runner tunnels are
      # WebSockets that idle between turns, so the default 60s read timeout
      # would sever live sessions.
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
      '';
    };
  };
}
