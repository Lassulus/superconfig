{ config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/baseX.nix
    ../../2configs/pipewire.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/programs.nix
    ../../2configs/bitcoin.nix
    ../../2configs/browsers.nix
    ../../2configs/games.nix
    ../../2configs/pass.nix
    ../../2configs/steam.nix
    ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/mail.nix
    ../../2configs/syncthing.nix
    ../../2configs/br.nix
    ../../2configs/ableton.nix
    ../../2configs/dunst.nix
    ../../2configs/rtl-sdr.nix
    ../../2configs/print.nix
    ../../2configs/network-manager.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/ppp/x220-modem.nix
    ../../2configs/ppp/umts-stick.nix
    ../../2configs/consul.nix
    ../../2configs/networkd.nix
    ../../2configs/autotether.nix
    {
      krebs.iptables.tables.filter.INPUT.rules = [
        #risk of rain
        { predicate = "-p tcp --dport 11100"; target = "ACCEPT"; }
        #quake3
        { predicate = "-p tcp --dport 27950:27965"; target = "ACCEPT"; }
        { predicate = "-p udp --dport 27950:27965"; target = "ACCEPT"; }
      ];
    }
    {
      services.nginx = {
        enable = true;
        virtualHosts.default = {
          default = true;
          serverAliases = [
            "localhost"
            "${config.krebs.build.host.name}"
            "${config.krebs.build.host.name}.r"
          ];
          locations."~ ^/~(.+?)(/.*)?\$".extraConfig = ''
            alias /home/$1/public_html$2;
          '';
        };
      };
    }
    {
      services.redis.enable = true;
    }
    {
      environment.systemPackages = [
        pkgs.ovh-zone
        pkgs.bank
        pkgs.adb-sync
        pkgs.transgui
      ];
    }
    {
      services.tor = {
        enable = true;
        client.enable = true;
      };
    }
  ];

  krebs.build.host = config.krebs.hosts.mors;

  environment.systemPackages = with pkgs; [
    acronym
    brain
    cac-api
    sshpass
    get
    hashPassword
    urban
    mk_sql_pair
    remmina
    transmission

    macchanger

    dnsutils
    woeusb
    (pkgs.writeDashBin "play-on" ''
      HOST=$(echo 'styx\nshodan' | fzfmenu)
      ssh -t "$HOST" -- mpv "$@"
    '')
  ];

  #TODO: fix this shit
  ##fprint stuff
  ##sudo fprintd-enroll $USER to save fingerprints
  #services.fprintd.enable = true;
  #security.pam.services.sudo.fprintAuth = true;

  users.extraGroups = {
    loot = {
      members = [
        config.users.extraUsers.mainUser.name
        "firefox"
        "chromium"
        "google"
        "virtual"
      ];
    };
  };

  nixpkgs.config.android_sdk.accept_license = true;
  programs.adb.enable = true;


  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
  };


  # It may leak your data, but look how FAST it is!1!!
  # https://make-linux-fast-again.com/
  boot.kernelParams = [
    "noibrs"
    "noibpb"
    "nopti"
    "nospectre_v2"
    "nospectre_v1"
    "l1tf=off"
    "nospec_store_bypass_disable"
    "no_stf_barrier"
    "mds=off"
    "mitigations=off"
  ];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  nix.trustedUsers = [ "root" "lass" ];

  services.nscd.enableNsncd = true;

}
