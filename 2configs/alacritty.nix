{ pkgs, ... }:
let

  alacritty-cfg =
    extrVals:
    pkgs.writers.writeTOML "alacritty.toml" (
      {
        font =
          let
            family = "IosevkaTerm Nerd Font";
          in
          {
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
      }
      // extrVals
    );

  alacritty = pkgs.symlinkJoin {
    name = "alacritty";
    paths = [
      (pkgs.writeDashBin "alacritty" ''
        # ${pkgs.alacritty}/bin/alacritty --config-file /var/theme/config/alacritty.toml msg create-window "$@" ||
        ${pkgs.alacritty}/bin/alacritty --config-file /var/theme/config/alacritty.toml "$@"
      '')
      pkgs.alacritty
    ];
  };

in
{
  environment.etc = {
    "themes/light/alacritty.toml".source = alacritty-cfg {
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
          red = "#cc241d";
          green = "#98971a";
          yellow = "#d79921";
          blue = "#458588";
          magenta = "#b16286";
          cyan = "#689d6a";
          white = "#7c6f64";
        };

        # Bright colors
        bright = {
          black = "#928374";
          red = "#9d0006";
          green = "#79740e";
          yellow = "#b57614";
          blue = "#076678";
          magenta = "#8f3f71";
          cyan = "#427b58";
          white = "#3c3836";
        };
      };
    };
    "themes/dark/alacritty.toml".source = alacritty-cfg {
      colors = {
        # Default colors
        primary = {
          background = "#000000";
          foreground = "#ffffff";
        };
        cursor = {
          text = "#F81CE5";
          cursor = "#ffffff";
        };

        # Normal colors
        normal = {
          black = "#000000";
          red = "#fe0100";
          green = "#33ff00";
          yellow = "#feff00";
          blue = "#0066ff";
          magenta = "#cc00ff";
          cyan = "#00ffff";
          white = "#d0d0d0";
        };

        # Bright colors
        bright = {
          black = "#808080";
          red = "#fe0100";
          green = "#33ff00";
          yellow = "#feff00";
          blue = "#0066ff";
          magenta = "#cc00ff";
          cyan = "#00ffff";
          white = "#FFFFFF";
        };
      };
    };
  };
  environment.systemPackages = [ alacritty ];
}
