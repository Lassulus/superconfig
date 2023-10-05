{ config, lib, pkgs, ... }: let

  alacritty-cfg = extrVals: builtins.toJSON ({
    font = let
      family = "Iosevka Term SS15";
    in {
      normal = {
        family = family;
        style = "Regular";
      };
      bold = {
        family = family;
        style = "Bold";
      };
      italic = {
        family = family;
        style = "Italic";
      };
      bold_italic = {
        family = family;
        style = "Bold Italic";
      };
      size = 12;
    };
    live_config_reload = true;
    window.dimensions = {
      columns = 80;
      lines = 20;
    };
    env.WINIT_X11_SCALE_FACTOR = "1.0";
    # window.opacity = 0;
    hints.enabled = [
      {
        regex = ''(mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\u0000-\u001F\u007F-\u009F<>"\s{-}\^⟨⟩`]+'';
        command = "/run/current-system/sw/bin/xdg-open";
        post_processing = true;
        mouse.enabled = true;
        binding = {
          key = "U";
          mods = "Alt";
        };
      }
    ];
  } // extrVals);

  alacritty = pkgs.symlinkJoin {
    name = "alacritty";
    paths = [
      (pkgs.writeDashBin "alacritty" ''
        ${pkgs.alacritty}/bin/alacritty --config-file /var/theme/config/alacritty.yaml msg create-window "$@" ||
        ${pkgs.alacritty}/bin/alacritty --config-file /var/theme/config/alacritty.yaml "$@"
      '')
      pkgs.alacritty
    ];
  };

in {
  environment.etc = {
    "themes/light/alacritty.yaml".text = alacritty-cfg {
      colors = {
        # Default colors
        primary = {
          # hard contrast: background = '#f9f5d7'
          # background = "#fbf1c7";
          background = "#f9f5d7";
          # soft contrast: background = '#f2e5bc'
          foreground = "#3c3836";
        };

        # Normal colors
        normal = {
          black = "#fbf1c7";
          red =     "#cc241d";
          green =   "#98971a";
          yellow =  "#d79921";
          blue =    "#458588";
          magenta = "#b16286";
          cyan =    "#689d6a";
          white =   "#7c6f64";
        };

        # Bright colors
        bright = {
          black =   "#928374";
          red =     "#9d0006";
          green =   "#79740e";
          yellow =  "#b57614";
          blue =    "#076678";
          magenta = "#8f3f71";
          cyan =    "#427b58";
          white =   "#3c3836";
        };
      };
    };
    "themes/dark/alacritty.yaml".text = alacritty-cfg {
      colors = {
        # Default colors
        primary = {
          background = "0x000000";
          foreground = "0xffffff";
        };
        cursor = {
          text = "0xF81CE5";
          cursor = "0xffffff";
        };

        # Normal colors
        normal = {
          black = "0x000000";
          red = "0xfe0100";
          green = "0x33ff00";
          yellow = "0xfeff00";
          blue = "0x0066ff";
          magenta = "0xcc00ff";
          cyan = "0x00ffff";
          white = "0xd0d0d0";
        };

        # Bright colors
        bright = {
          black = "0x808080";
          red = "0xfe0100";
          green = "0x33ff00";
          yellow = "0xfeff00";
          blue = "0x0066ff";
          magenta = "0xcc00ff";
          cyan = "0x00ffff";
          white = "0xFFFFFF";
        };
      };
    };
  };
  environment.systemPackages = [ alacritty ];
}
