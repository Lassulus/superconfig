{ pkgs, ... }:
{
  imports = [
    ../lib/wayland.nix
  ];
  # xdg.portal.enable = true;
  # xdg.portal.wlr.enable = true;
  # fonts.enableDefaultPackages = true;

  # security.polkit.enable = true;
  # security.pam.services.swaylock = { };

  # programs.dconf.enable = lib.mkDefault true;
  # programs.xwayland.enable = lib.mkDefault true;

  # environment.sessionVariables = {
  #   MOZ_ENABLE_WAYLAND = "1";
  #   XDG_SESSION_TYPE = "wayland";
  #   XDG_CURRENT_DESKTOP = "qtile";
  #   SDL_VIDEODRIVER = "wayland";
  #   QT_QPA_PLATFORM = "wayland";
  #   QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  #   _JAVA_AWT_WM_NONREPARENTING = "1";
  # };

  # # wayland stuff
  # environment.systemPackages = [
  #   pkgs.rofi-wayland
  #   pkgs.wtype
  #   pkgs.otpmenu
  #   pkgs.qtile
  #   pkgs.swaylock
  #   pkgs.copyq
  #   (pkgs.writers.writeDashBin "pass_menu" ''
  #     set -efux
  #     password=$(
  #       (cd $HOME/.password-store; find -type f -name '*.gpg') |
  #         sed -e 's/\.gpg$//' |
  #         rofi -dmenu -p 'Password: ' |
  #         xargs -I{} pass show {} |
  #         tr -d '\n'
  #     )
  #     echo -n "$password" | ${pkgs.wtype}/bin/wtype -d 10 -s 400 -
  #   '')
  #   (pkgs.writeTextFile {
  #     name = "configure-gtk";
  #     destination = "/bin/configure-gtk";
  #     executable = true;
  #     text = let
  #       schema = pkgs.gsettings-desktop-schemas;
  #       datadir = "${schema}/share/gsettings-schemas/${schema.name}";
  #     in ''
  #       export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
  #       gnome_schema=org.gnome.desktop.interface
  #       gsettings set $gnome_schema gtk-theme 'Dracula'
  #     '';
  #   })
  # ];

  services.xserver.windowManager.qtile = {
    enable = true;
    backend = "wayland";
  };

  environment.etc."qtile.py".source = ./qtile.py;
  environment.systemPackages = [
    (pkgs.writeTextFile {
      name = "qtile.py";
      destination = "/etc/xdg/qtile.py";
      text = builtins.readFile ./qtile.py;
    })
    (pkgs.writeScriptBin "startx" ''
      qtile start -b wayland -c /etc/qtile.py
    '')
    pkgs.copyq
  ];
}
