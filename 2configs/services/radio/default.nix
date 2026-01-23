{
  self,
  config,
  pkgs,
  lib,
  ...
}:

let
  name = "radio";

  music_dir = "/var/music";

  # dash 0.5.13 has a regression where `read` builtin discards input when stdin is a socket
  # This breaks htgen which uses tcpserver. Pin htgen's dash to 0.5.12 until upstream fixes it.
  # See: https://git.kernel.org/pub/scm/utils/dash/dash.git/commit/?id=1d072e9c3292281a7eee54c41fec117ff22723e5
  dash-0_5_12 = pkgs.dash.overrideAttrs (_old: rec {
    version = "0.5.12";
    src = pkgs.fetchurl {
      url = "http://gondor.apana.org.au/~herbert/dash/files/dash-${version}.tar.gz";
      hash = "sha256-akdKxG6LCzKRbExg32lMggWNMpfYs4W3RQgDDKSo8oo=";
    };
  });

  htgen-fixed = pkgs.htgen.override {
    pkgs = pkgs // {
      dash = dash-0_5_12;
    };
  };

  skip_track = pkgs.writers.writeBashBin "skip_track" ''
    set -eu

    # TODO come up with new rating, without moving files
    # current_track=$(${pkgs.curl}/bin/curl -fSs http://localhost:8002/current | ${pkgs.jq}/bin/jq -r .filename)
    # track_infos=$(${print_current}/bin/print_current)
    # skip_count=$(${pkgs.attr}/bin/getfattr -n user.skip_count --only-values "$current_track" || echo 0)
    # if [[ "$current_track" =~ .*/the_playlist/music/.* ]] && [ "$skip_count" -le 2 ]; then
    #   skip_count=$((skip_count+1))
    #   ${pkgs.attr}/bin/setfattr -n user.skip_count -v "$skip_count" "$current_track"
    #   echo skipping: "$track_infos" skip_count: "$skip_count"
    # else
    #   mkdir -p "$music_dir"/the_playlist/.graveyard/
    #   mv "$current_track" "$music_dir"/the_playlist/.graveyard/
    #   echo killing: "$track_infos"
    # fi
    ${pkgs.curl}/bin/curl -fSs -X POST http://localhost:8002/skip |
      ${pkgs.jq}/bin/jq -r '.filename'
  '';

  good_track = pkgs.writeBashBin "good_track" ''
    set -eu

    current_track=$(${pkgs.curl}/bin/curl -fSs http://localhost:8002/current | ${pkgs.jq}/bin/jq -r .filename)
    track_infos=$(${print_current}/bin/print_current)
    # TODO come up with new rating, without moving files
    # if [[ "$current_track" =~ .*/the_playlist/music/.* ]]; then
    #   ${pkgs.attr}/bin/setfattr -n user.skip_count -v 0 "$current_track"
    # else
    #   mv "$current_track" "$music_dir"/the_playlist/music/ || :
    # fi
    echo good: "$track_infos"
  '';

  print_current = pkgs.writeDashBin "print_current" ''
    file=$(${pkgs.curl}/bin/curl -fSs http://localhost:8002/current |
      ${pkgs.jq}/bin/jq -r '.filename' |
      ${pkgs.gnused}/bin/sed 's,^${music_dir},,'
    )
    link=$(${pkgs.curl}/bin/curl http://localhost:8002/current |
      ${pkgs.jq}/bin/jq -r '.filename' |
      ${pkgs.gnused}/bin/sed 's@.*\(.\{11\}\)\.ogg@https://youtu.be/\1@'
    )
    echo "$file": "$link"
  '';

in
{
  imports = [
    ./news.nix
    ./weather.nix
    self.inputs.stockholm.nixosModules.acl
    # self.inputs.stockholm.nixosModules.reaktor2
  ];

  users.users = {
    "${name}" = rec {
      inherit name;
      createHome = true;
      group = name;
      uid = pkgs.stockholm.lib.genid_uint31 name;
      description = "radio manager";
      home = "/home/${name}";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [
        self.keys.ssh.barnacle.public
        self.keys.ssh.yubi_pgp.public
        self.keys.ssh.yubi1.public
        self.keys.ssh.yubi2.public
        self.keys.ssh.solo2.public
      ];
      packages = [
        good_track
        skip_track
        print_current
      ];
    };
  };

  users.groups = {
    "radio" = { };
  };

  systemd.services.radio_watcher = {
    wantedBy = [ "multi-user.target" ];
    after = [ "radio.service" ];
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "radio_watcher" ''
        set -efux
        while :; do
          ${pkgs.curl}/bin/curl -Ss http://localhost:8000/radio.ogg -o /dev/null
          ${pkgs.systemd}/bin/systemctl restart radio
          sleep 60
        done
      '';
      Restart = "on-failure";
    };
  };

  services.liquidsoap.streams.radio = ./radio.liq;
  systemd.services.radio = {
    environment = {
      RADIO_PORT = "8002";
      HOOK_TRACK_CHANGE = pkgs.writers.writeDash "on_change" ''
        set -xefu
        LIMIT=100000 #how many tracks to keep in the history
        HISTORY_FILE=/var/lib/radio/recent

        listeners=$(${pkgs.curl}/bin/curl -fSs http://localhost:8000/status-json.xsl |
          ${pkgs.jq}/bin/jq '[.icestats.source[].listeners] | add' || echo 0)
        echo "$(${pkgs.coreutils}/bin/date -Is)" "$filename" | ${pkgs.coreutils}/bin/tee -a "$HISTORY_FILE"
        echo "$(${pkgs.coreutils}/bin/tail -$LIMIT "$HISTORY_FILE")" > "$HISTORY_FILE"
      '';
      MUSIC = "${music_dir}/the_playlist";
      ICECAST_HOST = "localhost";
    };
    path = [
      pkgs.yt-dlp
      pkgs.bubblewrap
    ];
    serviceConfig.User = lib.mkForce "radio";
  };

  nixpkgs.config.packageOverrides = opkgs: {
    liquidsoap = opkgs.liquidsoap.override {
      runtimePackages = with opkgs; [
        bubblewrap
        curl
        ffmpeg
        yt-dlp
      ];
    };
    icecast = opkgs.icecast.overrideAttrs (old: rec {
      version = "2.5-beta3";

      src = pkgs.fetchurl {
        url = "http://downloads.xiph.org/releases/icecast/icecast-${version}.tar.gz";
        sha256 = "sha256-4FDokoA9zBDYj8RAO/kuTHaZ6jZYBLSJZiX/IYFaCW8=";
      };

      NIX_CFLAGS_COMPILE = "-Wno-error=implicit-function-declaration";

      buildInputs = old.buildInputs ++ [ pkgs.pkg-config ];
    });
  };
  services.icecast = {
    enable = true;
    hostname = "radio.lassul.us";
    admin.password = "hackme";
    extraConf = ''
      <authentication>
        <source-password>hackme</source-password>
        <admin-user>admin</admin-user>
        <admin-password>hackme</admin-password>
      </authentication>
      <logging>
        <accesslog>-</accesslog>
        <errorlog>-</errorlog>
        <loglevel>3</loglevel>
      </logging>
      <mount type="normal">
        <mount-name>/radio.badge</mount-name>
        <queue-size>2048000</queue-size>
        <burst-size>128000</burst-size>
      </mount>
    '';
  };

  networking.firewall.interfaces.retiolum.allowedTCPPorts = [
    8001
    8002
  ];

  krebs.htgen.radio = {
    package = htgen-fixed;
    port = 8001;
    user = {
      name = "radio";
    };
    scriptFile = pkgs.writeDash "radio" ''
      set -x
      case "''${Method:-} ''${Request_URI:-}" in
        "POST /skip")
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          msg=$(${skip_track}/bin/skip_track)
          echo "$msg"
          exit
        ;;
        "POST /good")
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          msg=$(${good_track}/bin/good_track)
          echo "$msg"
          exit
        ;;
      esac
    '';
  };

  security.acme.certs."radio.r".server = config.krebs.ssl.acmeURL;

  networking.firewall.allowedTCPPorts = [
    80
    8000
  ];
  services.nginx = {
    enable = true;
    virtualHosts."radio.r" = {
      enableACME = true;
      addSSL = true;
      locations."/".extraConfig = ''
        # https://github.com/aswild/icecast-notes#core-nginx-config
        proxy_pass http://localhost:8000;
        # Disable request size limit, very important for uploading large files
        client_max_body_size 0;

        # Enable support `Transfer-Encoding: chunked`
        chunked_transfer_encoding on;

        # Disable request and response buffering, minimize latency to/from Icecast
        proxy_buffering off;
        proxy_request_buffering off;

        # Icecast needs HTTP/1.1, not 1.0 or 2
        proxy_http_version 1.1;

        # Forward all original request headers
        proxy_pass_request_headers on;

        # Set some standard reverse proxy headers. Icecast server currently ignores these,
        # but may support them in a future version so that access logs are more useful.
        proxy_set_header  Host              $host;
        proxy_set_header  X-Real-IP         $remote_addr;
        proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto $scheme;

        # get source ip for weather reports
        proxy_set_header user-agent "$http_user_agent; client-ip=$remote_addr";
      '';
      locations."= /recent".extraConfig = ''
        default_type "text/plain";
        alias /var/lib/radio/recent;
      '';
      locations."= /current".extraConfig = ''
        proxy_pass http://localhost:8002;
      '';
      locations."= /skip".extraConfig = ''
        proxy_pass http://localhost:8001;
      '';
      locations."= /good".extraConfig = ''
        proxy_pass http://localhost:8001;
      '';
      locations."= /radio.sh".alias = pkgs.writeScript "radio.sh" ''
        #!/bin/sh
        trap 'exit 0' EXIT
        while sleep 1; do
          mpv \
            --cache-secs=0 --demuxer-readahead-secs=0 --untimed --cache-pause=no \
            'http://radio.lassul.us/radio.ogg'
        done
      '';
      locations."= /controls".extraConfig = ''
        default_type "text/html";
        alias ${./controls.html};
      '';
      extraConfig = ''
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
      '';
    };
  };
  services.syncthing.settings.folders."/home/lass/tmp/the_playlist" = {
    path = lib.mkForce "/var/music/the_playlist";
    devices = [
      "mors"
      "prism"
      "radio"
    ];
  };
  krebs.acl."/var/music/the_playlist"."u:lass:X".parents = true;
  krebs.acl."/var/music/the_playlist"."u:lass:rwX" = { };
  krebs.acl."/var/music/the_playlist"."u:radio:rwX" = { };
}
