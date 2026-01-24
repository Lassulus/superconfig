{ pkgs, ... }:
let
  kitty-cfg = pkgs.writeText "kitty.conf" ''
    # Font configuration
    font_family IosevkaTerm Nerd Font
    bold_font IosevkaTerm Nerd Font Bold
    italic_font IosevkaTerm Nerd Font Italic
    bold_italic_font IosevkaTerm Nerd Font Bold Italic
    font_size 12

    # Window settings
    initial_window_width 80c
    initial_window_height 20c

    # Enable remote control for runtime theme switching
    allow_remote_control yes
    listen_on unix:/tmp/kitty-socket

    # Include theme colors from /var/theme/config
    include /var/theme/config/kitty-colors.conf

    # URL handling
    open_url_with /run/current-system/sw/bin/xdg-open
    detect_urls yes
  '';

  kitty = pkgs.symlinkJoin {
    name = "kitty";
    paths = [
      (pkgs.writeDashBin "kitty" ''
        ${pkgs.kitty}/bin/kitty --config ${kitty-cfg} "$@"
      '')
      pkgs.kitty
    ];
  };

  # Light theme colors (Gruvbox Light)
  lightColors = ''
    foreground #3c3836
    background #f9f5d7

    cursor #3c3836
    cursor_text_color #f9f5d7

    # Normal colors
    color0 #fbf1c7
    color1 #cc241d
    color2 #98971a
    color3 #d79921
    color4 #458588
    color5 #b16286
    color6 #689d6a
    color7 #7c6f64

    # Bright colors
    color8 #928374
    color9 #9d0006
    color10 #79740e
    color11 #b57614
    color12 #076678
    color13 #8f3f71
    color14 #427b58
    color15 #3c3836
  '';

  # Dark theme colors
  darkColors = ''
    foreground #ffffff
    background #000000

    cursor #ffffff
    cursor_text_color #F81CE5

    # Normal colors
    color0 #000000
    color1 #fe0100
    color2 #33ff00
    color3 #feff00
    color4 #0066ff
    color5 #cc00ff
    color6 #00ffff
    color7 #d0d0d0

    # Bright colors
    color8 #808080
    color9 #fe0100
    color10 #33ff00
    color11 #feff00
    color12 #0066ff
    color13 #cc00ff
    color14 #00ffff
    color15 #FFFFFF
  '';

in
{
  environment.etc = {
    "themes/light/kitty-colors.conf".text = lightColors;
    "themes/dark/kitty-colors.conf".text = darkColors;
  };
  environment.systemPackages = [ kitty ];
}
