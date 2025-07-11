{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/pipewire.nix
    ../../2configs/autoupdate.nix
    {
      users.mutableUsers = lib.mkForce true;
      # bubsy config
      users.users.bubsy = {
        uid = 1001;
        home = "/home/bubsy";
        group = "users";
        createHome = true;
        extraGroups = [
          "audio"
          "networkmanager"
          "pipewire"
          "video"
          # "plugdev"
        ];
        useDefaultShell = true;
        isNormalUser = true;
      };
      networking.networkmanager.enable = true;
      networking.wireless.enable = lib.mkForce false;
      # programs.chromium = {
      #   enable = true;
      #   extensions = [
      #     "cjpalhdlnbpafiamejdnhcphjbkeiagm" # ublock origin
      #   ];
      # };
      environment.systemPackages = with pkgs; [
        kdePackages.ark
        pavucontrol
        #firefox
        chromium
        hexchat
        networkmanagerapplet
        libreoffice
        audacity
        zathura
        wine
        geeqie
        vlc
        zsnes
        telegram-desktop
      ];
      # services.udev.packages = [ pkgs.ledger-udev-rules ];
      nixpkgs.config.firefox.enableAdobeFlash = true;
      services.xserver.enable = true;
      services.xserver.displayManager.sddm.enable = true;
      services.xserver.desktopManager.plasma6.enable = true;
      services.displayManager.sddm.wayland.enable = true;
      services.tlp.enable = lib.mkForce false;
      services.xserver.layout = "de";
    }
    {
      users = {
        groups.plugdev = { };
        users = {
          bitcoin = {
            name = "bitcoin";
            description = "user for bitcoin stuff";
            home = "/home/bitcoin";
            isNormalUser = true;
            useDefaultShell = true;
            createHome = true;
            extraGroups = [
              "audio"
              "networkmanager"
              "plugdev"
            ];
            packages = [
              pkgs.electrum
              pkgs.ledger-live-desktop
            ];
          };
        };
      };
      hardware.ledger.enable = true;
      security.sudo.extraConfig = ''
        bubsy ALL=(bitcoin) NOPASSWD: ALL
      '';
    }
    {
      #remote control
      environment.systemPackages = with pkgs; [
        x11vnc
        # torbrowser
      ];
      krebs.iptables.tables.filter.INPUT.rules = [
        {
          predicate = "-p tcp -i retiolum --dport 5900";
          target = "ACCEPT";
        }
      ];
    }
  ];

  time.timeZone = "Europe/Berlin";

  hardware.trackpoint = {
    enable = true;
    sensitivity = 220;
    speed = 0;
    emulateWheel = true;
  };

  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
  '';

  krebs.build.host = config.krebs.hosts.daedalus;
}
