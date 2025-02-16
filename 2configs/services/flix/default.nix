{ config, pkgs, ... }:
{
  users.users.download = {
    isSystemUser = true;
    uid = 1001;
    group = "download";
  };
  users.groups.download.members = [ "transmission" ];
  services.transmission = {
    enable = true;
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
      if ! curl -SsfL http://transmission.r; then
        systemctl restart transmission*
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

  krebs.iptables = {
    enable = true;
    tables.filter.INPUT.rules = [
      {
        predicate = "-p tcp --dport 80";
        target = "ACCEPT";
      } # nginx web dir
      {
        predicate = "-p tcp --dport 443";
        target = "ACCEPT";
      } # nginx web dir
      {
        predicate = "-p tcp --dport 9091";
        target = "ACCEPT";
      } # transmission-web
      {
        predicate = "-p tcp --dport 51413";
        target = "ACCEPT";
      } # transmission-traffic
      {
        predicate = "-p udp --dport 51413";
        target = "ACCEPT";
      } # transmission-traffic
      {
        predicate = "-p tcp --dport 8096";
        target = "ACCEPT";
      } # jellyfin
      {
        predicate = "-p tcp --dport 8920";
        target = "ACCEPT";
      } # jellyfin
      {
        predicate = "-p udp --dport 1900";
        target = "ACCEPT";
      } # jellyfin
      {
        predicate = "-p udp --dport 7359";
        target = "ACCEPT";
      } # jellyfin

      # smbd
      {
        predicate = "-p tcp --dport 445";
        target = "ACCEPT";
      }
      {
        predicate = "-p tcp --dport 111";
        target = "ACCEPT";
      }
      {
        predicate = "-p udp --dport 111";
        target = "ACCEPT";
      }
      {
        predicate = "-p tcp --dport 2049";
        target = "ACCEPT";
      }
      {
        predicate = "-p udp --dport 2049";
        target = "ACCEPT";
      }
      {
        predicate = "-p tcp --dport 4000:4002";
        target = "ACCEPT";
      }
      {
        predicate = "-p udp --dport 4000:4002";
        target = "ACCEPT";
      }
    ];

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
    serviceConfig = {
      Restart = "always";
      ExecStart = pkgs.writers.writeDash "flix-index" ''
        set -efu

        DIR=/var/download
        cd "$DIR"
        while inotifywait -rq -e create -e move -e delete "$DIR"; do
          find . -type f > "$DIR"/index.tmp
          mv "$DIR"/index.tmp "$DIR"/index
        done
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
    package = pkgs.jellyseerr.overrideAttrs (_: {
      dontCheckForBrokenSymlinks = true;
    });
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

  # subtitles
  services.bazarr = {
    enable = true;
    openFirewall = true;
    user = "download";
    group = "download";
  };
}
