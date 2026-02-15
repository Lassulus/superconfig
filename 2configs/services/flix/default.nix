{ config, pkgs, ... }:
{
  users.users.download = {
    isSystemUser = true;
    uid = 1001;
    group = "download";
  };
  users.groups.download.members = [
    "transmission"
    "sabnzbd"
  ];
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    home = "/var/state/transmission";
    group = "download";
    downloadDirPermissions = "775";
    settings = {
      download-dir = "/var/download/transmission";
      incomplete-dir-enabled = false;
      rpc-bind-address = "::";
      message-level = 1;
      umask = 18;
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;
      # stop seeding after reaching 5.0 ratio
      ratio-limit = 5;
      ratio-limit-enabled = true;
      # limit concurrent seeding to reduce resource usage
      seed-queue-enabled = true;
      seed-queue-size = 20;
    };
  };

  # garbage collection for old torrents
  systemd.services.transmission-gc = {
    description = "Remove old completed torrents from Transmission";
    after = [ "transmission.service" ];
    path = [
      pkgs.transmission_4
      pkgs.jq
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.findutils
    ];
    script = ''
      set -efu
      TRANSMISSION_HOST="128.0.0.1:9091"
      MAX_AGE_DAYS=30
      MIN_RATIO=5.0

      # get list of all torrents as JSON
      torrents=$(transmission-remote "$TRANSMISSION_HOST" -l 2>/dev/null | tail -n +2 | head -n -1 || true)

      if [ -z "$torrents" ]; then
        echo "No torrents found"
        exit 0
      fi

      # process each torrent
      echo "$torrents" | while read -r line; do
        id=$(echo "$line" | awk '{print $1}' | tr -d '*')
        # skip if not a valid ID
        [ -z "$id" ] || [ "$id" = "ID" ] && continue

        # get torrent info
        info=$(transmission-remote "$TRANSMISSION_HOST" -t "$id" -i 2>/dev/null || continue)

        # extract ratio and completion status
        ratio=$(echo "$info" | grep "Ratio:" | awk '{print $2}')
        percent=$(echo "$info" | grep "Percent Done:" | awk '{print $3}' | tr -d '%')
        state=$(echo "$info" | grep "State:" | cut -d: -f2- | xargs)

        # skip if not 100% complete
        [ "$percent" != "100" ] && continue

        # check if ratio reached
        ratio_reached=false
        if [ -n "$ratio" ] && [ "$ratio" != "None" ]; then
          if awk "BEGIN {exit !($ratio >= $MIN_RATIO)}"; then
            ratio_reached=true
          fi
        fi

        # check age via date added
        date_added=$(echo "$info" | grep "Date added:" | cut -d: -f2- | xargs)
        if [ -n "$date_added" ]; then
          added_epoch=$(date -d "$date_added" +%s 2>/dev/null || echo 0)
          now_epoch=$(date +%s)
          age_days=$(( (now_epoch - added_epoch) / 86400 ))
        else
          age_days=0
        fi

        # remove if ratio reached OR older than max age
        if [ "$ratio_reached" = "true" ]; then
          echo "Removing torrent $id (ratio: $ratio >= $MIN_RATIO)"
          transmission-remote "$TRANSMISSION_HOST" -t "$id" --remove-and-delete
        elif [ "$age_days" -ge "$MAX_AGE_DAYS" ]; then
          echo "Removing torrent $id (age: $age_days days >= $MAX_AGE_DAYS)"
          transmission-remote "$TRANSMISSION_HOST" -t "$id" --remove-and-delete
        fi
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "transmission";
    };
  };

  systemd.timers.transmission-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
  systemd.services.transmission-watcher = {
    wantedBy = [ "multi-user.target" ];
    startAt = "*:0/5";
    path = [
      pkgs.curl
      pkgs.systemdMinimal
    ];
    script = ''
      set -efu -o pipefail
      # don't restart if transmission is currently starting or stopping
      state=$(systemctl show -p ActiveState --value transmission.service)
      if [ "$state" = "activating" ] || [ "$state" = "deactivating" ]; then
        echo "transmission is $state, skipping"
        exit 0
      fi
      # check if transmission responds (with timeout)
      if ! curl -SsfL --max-time 10 http://transmission.r; then
        echo "transmission not responding, restarting"
        systemctl restart transmission.service
      fi
    '';
  };

  security.acme.defaults.email = "spam@krebsco.de";
  security.acme.acceptTerms = true;
  security.acme.certs."yellow.r".server = config.krebs.ssl.acmeURL;
  security.acme.certs."jelly.r".server = config.krebs.ssl.acmeURL;
  security.acme.certs."radar.r".server = config.krebs.ssl.acmeURL;
  security.acme.certs."sonar.r".server = config.krebs.ssl.acmeURL;
  security.acme.certs."transmission.r".server = config.krebs.ssl.acmeURL;
  services.nginx = {
    enable = true;
    package = pkgs.nginx.override {
      modules = with pkgs.nginxModules; [
        fancyindex
      ];
    };
    virtualHosts."yellow.r" = {
      serverAliases = [ "flix.r" ];
      default = true;
      enableACME = true;
      addSSL = true;
      locations."/" = {
        root = "/var/download";
        extraConfig = ''
          fancyindex on;
          fancyindex_footer "/fancy.html";
          include ${pkgs.nginx}/conf/mime.types;
          include ${pkgs.writeText "extrMime" ''
            types {
              video/webm mkv;
            }
          ''};
          create_full_put_path on;
        '';
      };
      locations."/chatty" = {
        proxyPass = "http://localhost:3000";
        extraConfig = ''
          rewrite /chatty/(.*) /$1  break;
          proxy_set_header Host $host;
        '';
      };
      locations."= /fancy.html".extraConfig = ''
        alias ${pkgs.writeText "nginx_footer" ''
          <div id="mydiv">
            <!-- Include a header DIV with the same name as the draggable DIV, followed by "header" -->
            <div id="mydivheader">Click here to move</div>
              <iframe src="/chatty/index.html"></iframe>
          </div>
          <style>
          #mydiv {
            position: absolute;
            z-index: 9;
            background-color: #f1f1f1;
            border: 1px solid #d3d3d3;
            text-align: center;
          }

          #mydivheader {
            padding: 10px;
            cursor: move;
            z-index: 10;
            background-color: #2196F3;
            color: #fff;
          }
          </style>
          <script>
            // Make the DIV element draggable:
            dragElement(document.getElementById("mydiv"));

            function dragElement(elmnt) {
              var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
              if (document.getElementById(elmnt.id + "header")) {
                // if present, the header is where you move the DIV from:
                document.getElementById(elmnt.id + "header").onmousedown = dragMouseDown;
              } else {
                // otherwise, move the DIV from anywhere inside the DIV:
                elmnt.onmousedown = dragMouseDown;
              }

              function dragMouseDown(e) {
                e = e || window.event;
                e.preventDefault();
                // get the mouse cursor position at startup:
                pos3 = e.clientX;
                pos4 = e.clientY;
                document.onmouseup = closeDragElement;
                // call a function whenever the cursor moves:
                document.onmousemove = elementDrag;
              }

              function elementDrag(e) {
                e = e || window.event;
                e.preventDefault();
                // calculate the new cursor position:
                pos1 = pos3 - e.clientX;
                pos2 = pos4 - e.clientY;
                pos3 = e.clientX;
                pos4 = e.clientY;
                // set the element's new position:
                elmnt.style.top = (elmnt.offsetTop - pos2) + "px";
                elmnt.style.left = (elmnt.offsetLeft - pos1) + "px";
              }

              function closeDragElement() {
                // stop moving when mouse button is released:
                document.onmouseup = null;
                document.onmousemove = null;
              }
            }
          </script>
        ''};
      '';
    };
    virtualHosts."jelly.r" = {
      enableACME = true;
      addSSL = true;
      locations."/".extraConfig = ''
        proxy_pass http://localhost:8096/;
        proxy_set_header Accept-Encoding "";
      '';
    };
    virtualHosts."transmission.r" = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "http://128.0.0.1:9091";
      };
    };
    virtualHosts."radar.r" = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "http://localhost:7878";
      };
    };
    virtualHosts."sonar.r" = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyWebsockets = true;
        proxyPass = "http://localhost:8989";
        # sonar.r now has forced authentication
        extraConfig = ''
          proxy_set_header Authorization "Basic a3JlYnM6YWlkc2JhbGxz";
        '';
      };
    };
  };

  services.samba = {
    enable = true;
    enableNmbd = false;
    settings.global = {
      "hosts allow" = "42::/16 10.243.0.0/16 10.244.0.0/16 fdcc:c5da:5295:c853:d499::/80";
      "use sendfile" = "true";
      "disable netbios" = "true";
      "mangled names" = "illegal";
      "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=65536 SO_SNDBUF=65536";
      "load printers" = "false";
      "disable spoolss" = "true";
      "printcap name" = "/dev/null";
      "map to guest" = "Bad User";
      "max log size" = "50";
      "dns proxy" = "no";
      "security" = "user";
      "syslog only" = "yes";
    };
    shares.public = {
      comment = "Warez";
      path = "/var/download";
      public = "yes";
      "only guest" = "yes";
      "create mask" = "0644";
      "directory mask" = "2777";
      writable = "no";
      printable = "no";
    };
  };

  systemd.services.bruellwuerfel =
    let
      bruellwuerfelSrc = pkgs.fetchFromGitHub {
        owner = "krebs";
        repo = "bruellwuerfel";
        rev = "dc73adf69249fb63a4b024f1f3fbc9e541b27015";
        sha256 = "078jp1gbavdp8lnwa09xa5m6bbbd05fi4x5ldkkgin5z04hwlhmd";
      };
    in
    {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      environment = {
        IRC_CHANNEL = "#flix";
        IRC_NICK = "bruelli";
        IRC_SERVER = "irc.r";
        IRC_HISTORY_FILE = "/tmp/bruelli.history";
      };
      serviceConfig = {
        ExecStart = "${pkgs.deno}/bin/deno run -A ${bruellwuerfelSrc}/src/index.ts";
      };
    };

  networking.firewall.allowedTCPPorts = [
    80 # nginx
    443 # nginx
    9091 # transmission web
    8096 # jellyfin
    8920 # jellyfin
    51413 # transmission traffic
    445 # smbd
    111 # smbd
    2049 # smbd
    4000 # smbd
    4001 # smbd
    4002 # smbd
  ];
  networking.firewall.allowedUDPPorts = [
    51413 # transmission traffic
    1900 # jellyfin
    7359 # jellyfin
    111 # smbd
    2049 # smbd
    4000 # smbd
    4001 # smbd
    4002 # smbd
  ];
  krebs.iptables = {
    enable = true;
    tables.nat.PREROUTING.rules = [
      # transmission rpc port
      {
        predicate = "-i retiolum -p tcp --dport 9091";
        target = "DNAT --to-destination fdb4:3310:947::2";
        v4 = false;
      }
    ];
    tables.filter.FORWARD.policy = "ACCEPT"; # we need this so we can forward into the the transmission network namespace
  };

  systemd.services.flix-index = {
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.inotify-tools
    ];
    startAt = "hourly";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writers.writeDash "flix-index" ''
        set -efu
        index(){
          find . -type f > "$DIR"/index.tmp
          mv "$DIR"/index.tmp "$DIR"/index
        }

        DIR=/var/download
        cd "$DIR"
        index
      '';
    };
  };

  services.jellyfin = {
    enable = true;
    group = "download";
  };

  # request managment
  services.jellyseerr = {
    enable = true;
    openFirewall = true;
  };

  # movies
  services.radarr = {
    enable = true;
    openFirewall = true;
    user = "download";
    group = "download";
  };

  # shows
  services.sonarr = {
    enable = true;
    openFirewall = true;
    user = "download";
    group = "download";
  };
  # sonarr needs unsecure packages
  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-wrapped-6.0.36"
    "aspnetcore-runtime-6.0.36"
    "dotnet-sdk-wrapped-6.0.428"
    "dotnet-sdk-6.0.428"
  ];

  # indexers
  services.prowlarr = {
    enable = true;
    openFirewall = true;
  };

  # flaresolverr for bypassing cloudflare on some indexers
  services.flaresolverr = {
    enable = true;
    openFirewall = true;
  };

  # subtitles
  services.bazarr = {
    enable = true;
    openFirewall = true;
    user = "download";
    group = "download";
  };

  # usenet download client
  services.sabnzbd = {
    enable = true;
    group = "download";
    openFirewall = true;
  };
}
