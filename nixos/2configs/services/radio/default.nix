{ config, pkgs, lib, ... }:

let
  name = "radio";

  music_dir = "/var/music";

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

  set_irc_topic = pkgs.writeDash "set_irc_topic" ''
    ${pkgs.curl}/bin/curl -fsS --unix-socket /home/radio/reaktor.sock http://z/ \
      -H content-type:application/json \
      -d "$(${pkgs.jq}/bin/jq -n \
        --arg text "$1" '{
          command:"TOPIC",
          params:["#the_playlist",$text]
        }'
      )"
  '';

  write_to_irc = pkgs.writeDash "write_to_irc" ''
    ${pkgs.curl}/bin/curl -fsSv --unix-socket /home/radio/reaktor.sock http://z/ \
      -H content-type:application/json \
      -d "$(${pkgs.jq}/bin/jq -n \
        --arg text "$1" '{
          command:"PRIVMSG",
          params:["#the_playlist",$text]
        }'
      )"
  '';

in {
  imports = [
    ./news.nix
    ./weather.nix
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
      openssh.authorizedKeys.keys = with config.krebs.users; [
        lass.pubkey
      ];
    };
  };

  users.groups = {
    "radio" = {};
  };

  krebs.per-user.${name}.packages = with pkgs; [
    good_track
    skip_track
    print_current
  ];


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
        LIMIT=1000 #how many tracks to keep in the history
        HISTORY_FILE=/var/lib/radio/recent

        listeners=$(${pkgs.curl}/bin/curl -fSs http://localhost:8000/status-json.xsl |
          ${pkgs.jq}/bin/jq '[.icestats.source[].listeners] | add' || echo 0)
        echo "$(${pkgs.coreutils}/bin/date -Is)" "$filename" | ${pkgs.coreutils}/bin/tee -a "$HISTORY_FILE"
        echo "$(${pkgs.coreutils}/bin/tail -$LIMIT "$HISTORY_FILE")" > "$HISTORY_FILE"
        ${set_irc_topic} "playing: $filename listeners: $listeners"
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
    icecast = opkgs.icecast.overrideAttrs (old: rec {
      version = "2.5-beta3";

      src = pkgs.fetchurl {
        url = "http://downloads.xiph.org/releases/icecast/icecast-${version}.tar.gz";
        sha256 = "sha256-4FDokoA9zBDYj8RAO/kuTHaZ6jZYBLSJZiX/IYFaCW8=";
      };

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
    '';
  };

  krebs.iptables = {
    tables = {
      filter.INPUT.rules = [
        { predicate = "-p tcp --dport 8000"; target = "ACCEPT"; }
        { predicate = "-i retiolum -p tcp --dport 8001"; target = "ACCEPT"; }
        { predicate = "-i retiolum -p tcp --dport 8002"; target = "ACCEPT"; }
      ];
    };
  };

  # allow reaktor2 to modify files
  systemd.services."reaktor2-the_playlist".serviceConfig.DynamicUser = lib.mkForce false;
  systemd.services."reaktor2-the_playlist".serviceConfig.Group = lib.mkForce "radio";

  krebs.reaktor2.the_playlist = {
    hostname = "irc.hackint.org";
    port = "6697";
    useTLS = true;
    nick = "the_playlist";
    username = "radio";
    API.listen = "unix:/home/radio/reaktor.sock";
    plugins = [
      {
        plugin = "register";
        config = {
          channels = [
            "#the_playlist"
            "#krebs"
          ];
        };
      }
      {
        plugin = "system";
        config = {
          workdir = config.krebs.reaktor2.the_playlist.stateDir;
          hooks.PRIVMSG = [
            {
              activate = "match";
              pattern = "^(?:.*\\s)?\\s*the_playlist:\\s*([0-9A-Za-z._][0-9A-Za-z._-]*)(?:\\s+(.*\\S))?\\s*$";
              command = 1;
              arguments = [2];
              commands = {
                skip.filename = "${skip_track}/bin/skip_track";
                next.filename = "${skip_track}/bin/skip_track";
                bad.filename = "${skip_track}/bin/skip_track";

                good.filename = "${good_track}/bin/good_track";
                nice.filename = "${good_track}/bin/good_track";
                like.filename = "${good_track}/bin/good_track";

                current.filename = "${print_current}/bin/print_current";
                wish.filename = pkgs.writeDash "wish" ''
                  echo "youtube-dl:$1" | ${pkgs.curl}/bin/curl -fSs http://localhost:8002/wish -d @- > /dev/null
                '';
                wishlist.filename = pkgs.writeDash "wishlist" ''
                  ${pkgs.curl}/bin/curl -fSs http://localhost:8002/wish | ${pkgs.jq}/bin/jq -r '.[]'
                '';
                suggest.filename = pkgs.writeDash "suggest" ''
                  echo "$@" >> playlist_suggest
                '';
              };
            }
          ];
        };
      }
    ];
  };

  krebs.htgen.radio = {
    port = 8001;
    user = {
      name = "radio";
    };
    scriptFile = pkgs.writeDash "radio" ''
      case "$Method $Request_URI" in
        "POST /skip")
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          msg=$(${skip_track}/bin/skip_track)
          ${write_to_irc} "$msg"
          echo "$msg"
          exit
        ;;
        "POST /good")
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          msg=$(${good_track}/bin/good_track)
          ${write_to_irc} "$msg"
          echo "$msg"
          exit
        ;;
      esac
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
  services.nginx = {
    enable = true;
    virtualHosts."radio.r" = {
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
  services.syncthing.declarative.folders."the_playlist" = {
    path = "/var/music/the_playlist";
    devices = [ "mors" "phone" "prism" "omo" "radio" ];
  };
  krebs.acl."/var/music/the_playlist"."u:syncthing:X".parents = true;
  krebs.acl."/var/music/the_playlist"."u:syncthing:rwX" = {};
  krebs.acl."/var/music/the_playlist"."u:radio:rwX" = {};
}
