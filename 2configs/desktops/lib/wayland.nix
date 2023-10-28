{ pkgs, lib, ... }:
{
  imports = [
    ../../alacritty.nix
    ../../mpv.nix
    ../../power-action.nix
    ../../urxvt.nix
    ../../xdg-open.nix
    ../../yubikey.nix
    ../../tmux.nix
    ../../themes.nix
    ../../fonts.nix
    # ./pipewire.nix
    # ./tty-share.nix
    {
      users.users.mainUser.packages = [
        pkgs.sshuttle
      ];
      security.sudo.extraConfig = ''
        lass ALL= (root) NOPASSWD:SETENV: ${pkgs.sshuttle}/bin/.sshuttle-wrapped
      '';
    }
  ];
  users.users.mainUser.extraGroups = [ "audio" "pipewire" "video" "input" ];

  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  environment.systemPackages = [
    pkgs.ydotool
    pkgs.wl-clipboard
    pkgs.rofi
    pkgs.swaylock
    pkgs.glib
    pkgs.dracula-theme
    pkgs.gnome3.adwaita-icon-theme
    (pkgs.writers.writeDashBin "pass_menu" ''
      set -efu
      password=$(
        (cd $HOME/.password-store; find -type f -name '*.gpg') |
          sed -e 's/\.gpg$//' |
          rofi -dmenu -p 'Password: ' |
          xargs -I{} pass show {} |
          tr -d '\n'
      )
      echo -n "$password" | ${pkgs.wtype}/bin/wtype -d 10 -s 400 -
    '')
  ];

  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # gtk portal needed to make gtk apps happy
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
  fonts.enableDefaultPackages = true;
  programs.dconf.enable = lib.mkDefault true;

}
