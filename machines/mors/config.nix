{
  self,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/desktops/qtile/nixos.nix
    ../../2configs/pipewire.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/browsers.nix
    ../../2configs/pass.nix
    ../../2configs/steam.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/mail.nix
    ../../2configs/syncthing.nix
    ../../2configs/ableton.nix
    ../../2configs/dunst.nix
    ../../2configs/rtl-sdr.nix
    ../../2configs/printing
    ../../2configs/network-manager.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/consul.nix
    ../../2configs/networkd.nix
    ../../2configs/autotether.nix
    ../../2configs/autoupdate.nix
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
      services.redis.servers."".enable = true;
    }
    {
      environment.systemPackages = [
        self.packages.${pkgs.system}.bank
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
    android-tools
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

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  services.nscd.enableNsncd = true;

}
