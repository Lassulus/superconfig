{
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../alacritty.nix
    ../../power-action.nix
    ../../xdg-open.nix
    ../../yubikey.nix
    ../../tmux.nix
    ../../themes.nix
    ../../fonts.nix
    # ../pipewire.nix
    # ./tty-share.nix
    {
      users.users.mainUser.packages = [
        pkgs.sshuttle
        self.packages.${pkgs.system}.mpv
      ];
      security.sudo.extraConfig = ''
        lass ALL= (root) NOPASSWD:SETENV: ${pkgs.sshuttle}/bin/.sshuttle-wrapped
      '';
    }
  ];

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
  };

  users.users.mainUser.extraGroups = [
    "audio"
    "pipewire"
    "video"
    "input"
  ];

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-wlr
  ];
  # xdg.portal.wlr.enable = true;
  xdg.portal.config.common.default = "wlr";
  fonts.enableDefaultPackages = true;

  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  programs.dconf.enable = lib.mkDefault true;
  services.gnome.gnome-keyring.enable = lib.mkDefault true;
  programs.xwayland.enable = lib.mkDefault true;

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    NIXOS_OZONE_WL = "1"; # Hint for electron apps to use wayland
  };

  programs.wshowkeys.enable = true;

  environment.systemPackages = with pkgs; [
    # (gamescope.overrideAttrs (old: {
    #   patches = old.patches ++ [
    #     ./gamescope_libinput.patch
    #   ];
    #
    # }))
    swaylock-effects # lockscreen
    pavucontrol
    swayidle
    rofi-wayland
    rofi-rbw
    eog
    libnotify
    mako # notifications
    kanshi # auto-configure display outputs
    wdisplays # buggy with qtile?
    wlr-randr
    wl-clipboard
    wev
    blueberry
    grim # screenshots
    wtype
    zathura
    nsxiv

    pavucontrol
    evince
    libnotify
    pamixer
    file-roller
    xdg-utils
    # polkit agent
    polkit_gnome

    self.packages.${pkgs.system}.wifi-qr

    # gtk3 themes
    gsettings-desktop-schemas
    (pkgs.writers.writeDashBin "pass_menu" ''
      set -efux
      password=$(
        (cd $HOME/.password-store; find -type f -name '*.gpg') |
          sed -e 's/\.gpg$//' |
          rofi -dmenu -p 'Password: ' |
          xargs -I{} pass show {} |
          tr -d '\n'
      )
      echo -n "$password" | ${pkgs.wtype}/bin/wtype -d 10 -s 400 -
    '')
    (pkgs.writers.writeDashBin "screenshot" ''
      ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
    '')
    (pkgs.writers.writeDashBin "type_paste" ''
      ${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.wtype}/bin/wtype -d 10 -s 400 -
    '')
  ];

  environment.pathsToLink = [
    "/libexec" # for polkit
    "/share/gsettings-schemas" # for XDG_DATA_DIRS
  ];

  qt.platformTheme = "qt5ct";

  security.pam.services.swaylock = { };
  security.pam.services.swaylock.fprintAuth = true;

  # from nixpkgs/nixos/modules/services/system/systemd-lock-handler.md
  services.systemd-lock-handler.enable = true;

  systemd.user.services.swaylock = {
    description = "Screen locker for Wayland";
    documentation = [ "man:swaylock(1)" ];

    # If swaylock exits cleanly, unlock the session:
    onSuccess = [ "unlock.target" ];

    # When lock.target is stopped, stops this too:
    partOf = [ "lock.target" ];

    # Delay lock.target until this service is ready:
    before = [ "lock.target" ];
    wantedBy = [ "lock.target" ];

    serviceConfig = {
      # systemd will consider this service started when swaylock forks...
      Type = "forking";

      # ... and swaylock will fork only after it has locked the screen.
      ExecStart = "${lib.getExe pkgs.swaylock} --image /var/lib/wallpaper/wallpaper -f";

      # If swaylock crashes, always restart it immediately:
      Restart = "on-failure";
      RestartSec = 0;
    };
  };
}
