{
  self,
  config,
  lib,
  ...
}:
let
  slib = self.inputs.stockholm.lib;
in
{

  system.stateVersion = "23.05";
  imports = [
    ../../2configs
    {
      # helsinki migration
      users.users.root.openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIP4MIZG/hZR3Ib7faGDyK67Tk53Q1P7pE5cFIWwEFbrtAAAABHNzaDo="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHBR9+AP/K+CY3S66vAGFyD5CQfNe7mrpD+jpKp5YfFJAAAABHNzaDo= fabian_sk"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILVGDN7LfdnZQ0411u27288g+Nz8Z3qv5F280itDFArAAAAABHNzaDo="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIC9d1Di6VHunJrvzVQqvsCdZzO3dmNe7XpQ4BB1uaclnAAAABHNzaDo="
      ];
    }
    ./backup.nix
    # ../../2configs/autoupdate.nix
    ../../2configs/ssh-redirect.nix
    ../../2configs/retiolum.nix
    ../../2configs/libvirt.nix
    ../../2configs/websites/lassulus.nix
    ../../2configs/services/git/proxy.nix
    ../../2configs/monitoring/telegraf.nix
    ../../2configs/consul.nix
    {
      services.nginx.enable = true;
      imports = [
        ../../2configs/websites/domsen.nix
      ];
      # needed by domsen.nix ^^
      lass.usershadow = {
        enable = true;
      };

      krebs.iptables.tables.filter.INPUT.rules = [
        {
          predicate = "-p tcp --dport http";
          target = "ACCEPT";
        }
        {
          predicate = "-p tcp --dport https";
          target = "ACCEPT";
        }
      ];
    }
    {
      # TODO make new hfos.nix out of this vv
      users.users.riot = {
        uid = slib.genid_uint31 "riot";
        isNormalUser = true;
        extraGroups = [ "libvirtd" ];
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6o6sdTu/CX1LW2Ff5bNDqGEAGwAsjf0iIe5DCdC7YikCct+7x4LTXxY+nDlPMeGcOF88X9/qFwdyh+9E4g0nUAZaeL14Uc14QDqDt/aiKjIXXTepxE/i4JD9YbTqStAnA/HYAExU15yqgUdj2dnHu7OZcGxk0ZR1OY18yclXq7Rq0Fd3pN3lPP1T4QHM9w66r83yJdFV9szvu5ral3/QuxQnCNohTkR6LoJ4Ny2RbMPTRtb+jPbTQYTWUWwV69mB8ot5nRTP4MRM9pu7vnoPF4I2S5DvSnx4C5zdKzsb7zmIvD4AmptZLrXj4UXUf00Xf7Js5W100Ne2yhYyhq+35 riot@lagrange"
        ];
      };
      krebs.iptables.tables.filter.FORWARD.rules = lib.mkBefore [
        {
          v6 = false;
          predicate = "--destination 95.216.1.130";
          target = "ACCEPT";
        }
        {
          v6 = false;
          predicate = "--source 95.216.1.130";
          target = "ACCEPT";
        }
      ];
    }
    {
      users.users.tv = {
        uid = slib.genid_uint31 "tv";
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          config.krebs.users.tv.pubkey
        ];
      };
      users.users.makefu = {
        uid = slib.genid_uint31 "makefu";
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          config.krebs.users.makefu.pubkey
        ];
      };
      users.extraUsers.dritter = {
        uid = slib.genid_uint31 "dritter";
        isNormalUser = true;
        extraGroups = [
          "download"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnqOWDDk7QkSAvrSLkEoz7dY22+xPyv5JDn2zlfUndfavmTMfZvPx9REMjgULbcCSM4m3Ncf40yUjciDpVleGoEz82+p/ObHAkVWPQyXRS3ZRM2IJJultBHEFc61+61Pi8k3p5pBhPPaig6VncJ4uUuuNqen9jqLesSTVXNtdntU2IvnC8B8k1Kq6fu9q1T2yEOMxkD31D5hVHlqAly0LdRiYvtsRIoCSmRvlpGl70uvPprhQxhtoiEUeDqmIL7BG9x7gU0Swdl7R0/HtFXlFuOwSlNYDmOf/Zrb1jhOpj4AlCliGUkM0iKIJhgH0tnJna6kfkGKHDwuzITGIh6SpZ dritter@Janeway"
        ];
      };
      users.extraUsers.juhulian = {
        uid = 1339;
        isNormalUser = true;
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBQhLGvfv4hyQ/nqJGy1YgHXPSVl6igeWTroJSvAhUFgoh+rG+zvqY0EahKXNb3sq0/OYDCTJVuucc0hgCg7T2KqTqMtTb9EEkRmCFbD7F7DWZojCrh/an6sHneqT5eFvzAPZ8E5hup7oVQnj5P5M3I9keRHBWt1rq6q0IcOEhsFvne4qJc73aLASTJkxzlo5U8ju3JQOl6474ECuSn0lb1fTrQ/SR1NgF7jV11eBldkS8SHEB+2GXjn4Yrn+QUKOnDp+B85vZmVlJSI+7XR1/U/xIbtAjGTEmNwB6cTbBv9NCG9jloDDOZG4ZvzzHYrlBXjaigtQh2/4mrHoKa5eV juhulian@juhulian"
        ];
      };
      users.users.hellrazor = {
        uid = slib.genid_uint31 "hellrazor";
        isNormalUser = true;
        extraGroups = [
          "download"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDQFaYOWRUvHP6I37q9Dd4PJOq8FNQqAeJZ8pLx0G62uC450kbPGcG80rHHvXmk7HqQP6biJmMg48bOsvXAScPot2Qhp1Qc35CuUqVhLiTvUAsi8l/iJjhjZ23yRGDCAmW5+JIOzIvECkcbMnG7YoYAQ9trNGHe9qwGzQGhpt3QVClE23WtE3PVKRLQx1VbiabSnAm6tXVd2zpUoSdpWt8Gpi2taM4XXJ5+l744MNxFHvDapN5xqpYzwrA34Ii13jNLWcGbtgxESpR+VjnamdWByrkBsW4X5/xn2K1I1FrujaM/DBHV1QMaDKst9V8+uL5X7aYNt0OUBu2eyZdg6aujY2BYovB9uRyR1JIuSbA/a54MM96yN9WirMUufJF/YZrV0L631t9EW8ORyWUo1GRzMuBHVHQlfApj7NCU/jEddUuTqKgwyRgTmMFMUI4M0tRULAB/7pBE1Vbcx9tg6RsKIk8VkskfbBJW9Y6Sx6YoFlxPdgMNIrBefqEjIV62piP7YLMlvfIDCJ7TNd9dLN86XGggZ/nD5zt6SL1o61vVnw9If8pHosppxADPJsJvcdN6fOe16/tFAeE0JRo0jTcyFVTBGfhpey+rFfuW8wtUyuO5WPUxkOn7xMHGMWHJAtWX2vwVIDtLxvqn48B4SmEOpPD6ii+vcpwqAex3ycqBUQ=="
        ];
      };
    }
    {
      imports = [
        ../../2configs/services/matrix/proxy.nix
      ];
      services.nginx.virtualHosts."matrix.lassul.us" = {
        enableACME = lib.mkForce false;
        forceSSL = lib.mkForce false;
      };
    }
    ../../2configs/exim-smarthost.nix
    ../../2configs/privoxy-retiolum.nix
    ../../2configs/binary-cache/server.nix
    ../../2configs/binary-cache/proxy.nix
    ../../2configs/iodined.nix
    ../../2configs/paste.nix
    ../../2configs/syncthing.nix
    ../../2configs/container-networking.nix
    ../../2configs/bgt-bot
    (self.inputs.stockholm + "/krebs/2configs/mastodon-proxy.nix")
    {
      services.tor = {
        enable = true;
      };
    }
    {
      imports = [
        ../../2configs/realwallpaper.nix
      ];
      services.nginx.virtualHosts."lassul.us".locations = {
        "= /wallpaper-marker.png".extraConfig = ''
          alias /var/realwallpaper/realwallpaper-marker.png;
        '';
        "= /wallpaper.png".extraConfig = ''
          alias /var/realwallpaper/realwallpaper.png;
        '';
        "= /wallpaper-stars-berlin.png".extraConfig = ''
          alias /var/realwallpaper/realwallpaper-krebs-stars-berlin.png;
        '';
      };
    }
    ../../2configs/minecraft.nix
    {
      lass.nichtparasoup.enable = true;
      services.nginx = {
        enable = true;
        virtualHosts."lol.lassul.us" = {
          forceSSL = true;
          enableACME = true;
          locations."/".extraConfig = ''
            proxy_pass http://localhost:5001;
          '';
        };
      };
    }
    {
      imports = [
        ../../2configs/wiregrill.nix
      ];
      krebs.iptables.tables.nat.PREROUTING.rules = lib.mkOrder 999 [
        {
          v6 = false;
          predicate = "-s 10.244.0.0/16";
          target = "ACCEPT";
        }
        {
          v4 = false;
          predicate = "-s 42:1::/32";
          target = "ACCEPT";
        }
      ];
      krebs.iptables.tables.filter.FORWARD.rules = lib.mkBefore [
        {
          predicate = "-i wiregrill -o retiolum";
          target = "ACCEPT";
        }
        {
          predicate = "-i retiolum -o wiregrill";
          target = "ACCEPT";
        }
      ];
      krebs.iptables.tables.nat.POSTROUTING.rules = [
        {
          v4 = false;
          predicate = "-s 42:1::/32 ! -d 42:1::/48";
          target = "MASQUERADE";
        }
        {
          v6 = false;
          predicate = "-s 10.244.0.0/16 ! -d 10.244.0.0/16";
          target = "MASQUERADE";
        }
      ];
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;

        settings = {
          bind-interfaces = true;
          interface = [
            "wiregrill"
            "retiolum "
          ];
        };
      };
    }
    {
      krebs.iptables.tables.filter.INPUT.rules = [
        {
          predicate = "-p udp --dport 60000:61000";
          target = "ACCEPT";
        }
      ];
    }
    ../../2configs/services/coms/murmur.nix
    {
      # acme fallback for neoprism migration
      services.nginx.virtualHosts."lassul.us".acmeFallbackHost = "orange.r";
      services.nginx.virtualHosts."radio.lassul.us".acmeFallbackHost = "neoprism.r";
      services.nginx.virtualHosts."flix.lassul.us".acmeFallbackHost = "neoprism.r";
      services.nginx.virtualHosts."jitsi.lassul.us".acmeFallbackHost = "neoprism.r";
      services.nginx.virtualHosts."cgit.lassul.us".acmeFallbackHost = "orange.r";
      services.nginx.virtualHosts."mail.lassul.us".acmeFallbackHost = "neoprism.r";
      services.nginx.virtualHosts."mumble.lassul.us".acmeFallbackHost = "neoprism.r";
      services.nginx.virtualHosts."mail.ubikmedia.eu" = {
        enableACME = true;
        forceSSL = true;
        acmeFallbackHost = "ubik.r";
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "https://ubik.r";
        };
      };
    }
  ];

  krebs.build.host = config.krebs.hosts.prism;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
  };
}
