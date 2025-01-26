{ pkgs, ... }:
let

  switch-theme = pkgs.writers.writeDashBin "switch-theme" ''
    set -efux
    if [ "$1" = toggle ]; then
      if [ "$(${pkgs.coreutils}/bin/cat /var/theme/current_theme)" = dark ]; then
        ${placeholder "out"}/bin/switch-theme light
      else
        ${placeholder "out"}/bin/switch-theme dark
      fi
    elif test -e "/etc/themes/$1"; then
      ${pkgs.coreutils}/bin/mkdir -p /var/theme/config
      ${pkgs.rsync}/bin/rsync --chown=lass:users -a --delete "/etc/themes/$1/" /var/theme/config/
      echo "$1" > /var/theme/current_theme
      ${pkgs.coreutils}/bin/chown lass:users /var/theme/current_theme
      ${pkgs.xorg.xrdb}/bin/xrdb -merge /var/theme/config/xresources || : # wayland has no xresources
      ${pkgs.procps}/bin/pkill -HUP xsettingsd || :
      set +f
      GSETTINGS_SCHEMA_DIR=$(echo /run/current-system/sw/share/gsettings-schemas/*/*/schemas | sed s', ,:,g')
      export GSETTINGS_SCHEMA_DIR
      set -f
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$(cat /var/theme/config/gtk-theme)" || :
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme "prefer-$1" || :
    else
      echo "theme $1 not found"
    fi
  '';

in
{
  systemd.tmpfiles.rules = [
    "d /var/theme/ 755 lass users"
  ];
  environment.systemPackages = [
    switch-theme
    pkgs.dracula-theme
    pkgs.adwaita-icon-theme
  ];
  environment.etc = {
    "themes/light/gtk-theme".text = ''
      Adwaita
    '';
    "themes/light/xsettings.conf".text = ''
      Net/ThemeName "Adwaita"
    '';
    "themes/light/xresources".text = ''
      *background: #ffffff
      *foreground: #000000
    '';
    "themes/dark/gtk-theme".text = ''
      Dracula
    '';
    "themes/dark/xsettings.conf".text = ''
      Net/ThemeName "Dracula"
    '';
    "themes/dark/xresources".text = ''
      *background: #000000
      *foreground: #ffffff
    '';
  };
  # system.activationScripts.theme.text = ''
  #   export DISPLAY=:0
  #   if test -e /var/theme/current_theme; then
  #     ${switch-theme}/bin/switch-theme "$(cat /var/theme/current_theme)" ||
  #     ${switch-theme}/bin/switch-theme dark
  #   else
  #     ${switch-theme}/bin/switch-theme dark
  #   fi
  # '';
}
