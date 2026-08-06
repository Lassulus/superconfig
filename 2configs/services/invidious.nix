{ config, pkgs, ... }:

let
  domain = "yt.lassul.us";

  # local entry point of the residential exit pool (see 2configs/residential-exit.nix)
  proxyPort = 8118;
  companionPort = 8282;

  exit = host: config.krebs.hosts.${host}.nets.retiolum.ip4.addr;
in
{
  # invidious talks to companion over this key; it must not end up in the
  # world readable nix store, so it is generated once and handed to invidious
  # as a systemd credential and to companion as an EnvironmentFile.
  clan.core.vars.generators.invidious = {
    files."companion.json" = { };
    files."companion.env" = { };
    runtimeInputs = [
      pkgs.pwgen
      pkgs.jq
    ];
    script = ''
      key=$(pwgen -s 16 1)
      jq -n --arg key "$key" '{ invidious_companion_key: $key }' > "$out"/companion.json
      echo "SERVER_SECRET_KEY=$key" > "$out"/companion.env
    '';
  };

  services.invidious = {
    enable = true;
    inherit domain;
    nginx.enable = true;

    # Our nixpkgs pin is two invidious releases behind. 2.20260804.1 carries
    # the comments parser fixes (#5862, #5870): YouTube started emitting a
    # commentFilterContextViewModel node, which the packaged version feeds
    # straight into a Hash lookup -> "Expected Hash for #[]?(key : String),
    # not String" and a 500 on every comment request. Overriding just
    # versions.json is safe here: shard.lock is untouched between the two
    # tags, so the packaged shards.nix still applies, and the videojs hash is
    # unchanged. Drop this once the nixpkgs pin catches up (master has it).
    package = pkgs.invidious.override {
      versions = {
        invidious = {
          version = "2.20260804.1";
          date = "2026.08.04";
          commit = "48c6110a";
          hash = "sha256-YO+aJXphVfplAOjLtpTcWcqMcWgv4SHgoWNWhPOnz2M=";
        };
        videojs.hash = "sha256-jED3zsDkPN8i6GhBBJwnsHujbuwlHdsVpVqa1/pzSH4=";
      };
    };
    # credentials land at a fixed path, and the config script reads the file
    # as the (dynamic) invidious user, which plain vars files are not readable by
    extraSettingsFile = "/run/credentials/invidious.service/companion.json";
    settings = {
      # single user instance; accounts exist only for subscriptions/prefs.
      # The admin panel can flip this at runtime, but the unit is restarted
      # hourly (RuntimeMaxSec), so the config value always wins.
      registration_enabled = false;
      admins = [ "lassulus" ];

      # metadata, search and thumbnails leave through the residential pool too:
      # a datacenter IP gets rate limited on the innertube API within minutes
      http_proxy = {
        host = "127.0.0.1";
        port = proxyPort;
        user = "";
        password = "";
      };

      # "Proxy videos" must be on by default. Upstream defaults it off, which
      # makes invidious hand the browser raw googlevideo/youtube.com URLs on
      # the HLS, listen and download paths. Those URLs are minted for styx's
      # address (they carry ip=<exit>), so the client gets 403 -- and they
      # leak the exit IP. Everything has to come back through us.
      default_user_preferences.local = true;
      # public_url omitted on purpose: invidious then proxies /companion itself
      # instead of us maintaining a second nginx route
      invidious_companion = [
        { private_url = "http://127.0.0.1:${toString companionPort}/companion"; }
      ];
    };
  };

  systemd.services.invidious = {
    after = [ "podman-invidious-companion.service" ];
    wants = [ "podman-invidious-companion.service" ];
    serviceConfig.LoadCredential = [
      "companion.json:${config.clan.core.vars.generators.invidious.files."companion.json".path}"
    ];
  };

  # No anonymous playback: every stream byte comes off a residential line, so
  # the paths that move video require a real invidious session. auth_request
  # subrequests invidious' own authenticated API, which resolves the SID
  # cookie against the session_ids table -- a forged cookie gets 403 there, so
  # this is genuine authentication rather than a cookie-presence check.
  # Browsing/search stay open so the login page and UI still work.
  services.nginx.virtualHosts.${domain}.locations =
    let
      upstream = "http://127.0.0.1:${toString config.services.invidious.port}";
      gated = {
        proxyPass = upstream;
        extraConfig = ''
          auth_request /_session_check;
          proxy_buffering off;
        '';
      };
    in
    {
      "= /_session_check".extraConfig = ''
        internal;
        proxy_pass ${upstream}/api/v1/auth/preferences;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
      '';

      # companion serves all VOD audio/video; the rest carry HLS and the
      # non-companion fallbacks
      "/companion/" = gated;
      "/videoplayback" = gated;
      "/latest_version" = gated;
      "/api/manifest/" = gated;
    };

  # video streams are fetched by companion, not by invidious, so the proxy has
  # to be configured here as well or playback comes from the Hetzner address
  virtualisation.oci-containers = {
    backend = "podman";
    containers.invidious-companion = {
      image = "quay.io/invidious/invidious-companion:latest";
      environment = {
        HOST = "127.0.0.1";
        PORT = toString companionPort;
        PROXY = "http://127.0.0.1:${toString proxyPort}";
      };
      environmentFiles = [
        config.clan.core.vars.generators.invidious.files."companion.env".path
      ];
      volumes = [ "invidious-companion-cache:/var/tmp/youtubei.js" ];
      extraOptions = [
        # host netns so 127.0.0.1 means the same thing for both the listen
        # address and the proxy pool
        "--network=host"
        "--cap-drop=ALL"
        "--read-only"
        "--security-opt=no-new-privileges:true"
      ];
    };
  };

  # upstream only publishes a rolling tag, so pull it on a schedule
  systemd.services.invidious-companion-update = {
    startAt = "daily";
    script = ''
      ${pkgs.podman}/bin/podman pull ${config.virtualisation.oci-containers.containers.invidious-companion.image}
      systemctl restart podman-invidious-companion.service
      ${pkgs.podman}/bin/podman image prune -f
    '';
  };

  # TCP load balancer in front of the residential tinyproxies. styx is the
  # permanently-on box and takes all traffic; coaxmetal is a laptop and only
  # takes over while styx is unreachable. Deliberately not round-robin:
  # YouTube binds po_tokens and videoplayback URLs to the requesting address,
  # so alternating exits mid-session breaks playback.
  services.nginx.streamConfig = ''
    upstream residential_exits {
      server ${exit "styx"}:${toString proxyPort} max_fails=2 fail_timeout=60s;
      server ${exit "coaxmetal"}:${toString proxyPort} backup;
    }

    server {
      listen 127.0.0.1:${toString proxyPort};
      proxy_pass residential_exits;
      proxy_connect_timeout 10s;
      proxy_timeout 1h;
    }
  '';
}
