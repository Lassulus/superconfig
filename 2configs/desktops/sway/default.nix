{ pkgs, lib, ... }:
let

  term = "/run/current-system/sw/bin/alacritty";

  waybarConfig = pkgs.writeText "waybar-config.json" (
    builtins.toJSON {
      height = 30;
      spacing = 4;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
        "sway/scratchpad"
      ];
      modules-center = [ "sway/window" ];
      modules-right = [
        "idle_inhibitor"
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "temperature"
        "backlight"
        "battery"
        "clock"
        "tray"
      ];

      "sway/mode".format = "<span style=\"italic\">{}</span>";

      "sway/scratchpad" = {
        format = "{icon} {count}";
        show-empty = false;
        format-icons = [
          ""
          "󰏃"
        ];
        tooltip = true;
        tooltip-format = "{app}: {title}";
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰾪";
        };
      };

      tray.spacing = 10;

      clock = {
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "{:%Y-%m-%d}";
      };

      cpu = {
        format = "{usage}% 󰍛";
        tooltip = false;
      };

      memory.format = "{}% 󰘚";

      temperature = {
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = [
          "󰔏"
          "󰔏"
          "󰔏"
        ];
      };

      backlight = {
        format = "{percent}% {icon}";
        format-icons = [
          "󰃞"
          "󰃟"
          "󰃠"
        ];
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-full = "{capacity}% {icon}";
        format-charging = "{capacity}% 󰂄";
        format-plugged = "{capacity}% 󰚥";
        format-alt = "{time} {icon}";
        format-icons = [
          "󰂎"
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
      };

      network = {
        format-wifi = "{essid} ({signalStrength}%) 󰖩";
        format-ethernet = "{ipaddr}/{cidr} 󰈀";
        tooltip-format = "{ifname} via {gwaddr} 󰛳";
        format-linked = "{ifname} (No IP) 󰈀";
        format-disconnected = "Disconnected 󰖪";
        format-alt = "{ifname}: {ipaddr}/{cidr}";
      };

      pulseaudio = {
        format = "{volume}% {icon} {format_source}";
        format-bluetooth = "{volume}% {icon}󰂯 {format_source}";
        format-bluetooth-muted = "󰖁 {icon}󰂯 {format_source}";
        format-muted = "󰖁 {format_source}";
        format-source = "{volume}% 󰍬";
        format-source-muted = "󰍭";
        format-icons = {
          headphone = "󰋋";
          hands-free = "󰋎";
          headset = "󰋎";
          phone = "󰏲";
          portable = "󰏲";
          car = "󰄋";
          default = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
        };
        on-click = "pavucontrol";
      };
    }
  );

  waybarStyle = pkgs.writeText "waybar-style.css" ''
    @import "${pkgs.waybar}/etc/xdg/waybar/style.css";
    * {
      font-family: "Iosevka Nerd Font", monospace;
    }
  '';

in
{
  imports = [
    ../lib/wayland.nix
  ];
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export SWAYSOCK=/run/user/$(id -u)/sway-ipc.sock
    '';
  };

  systemd.user.services.waybar = {
    description = "Highly customizable Wayland bar for Sway";
    documentation = [ "man:waybar(5)" ];
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.waybar}/bin/waybar -c ${waybarConfig} -s ${waybarStyle}";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  environment.etc."sway/config".text = ''
    # Default config for sway
    #
    # Copy this to ~/.config/sway/config and edit it to your liking.
    #
    # Read `man 5 sway` for a complete reference.

    ### Variables
    #
    # Logo key. Use Mod1 for Alt.
    set $mod Mod4
    # Home row direction keys, like vim
    set $left h
    set $down j
    set $up k
    set $right l
    # Your preferred terminal emulator
    set $term ${term}
    # Your preferred application launcher
    # Note: pass the final command to swaymsg so that the resulting window can be opened
    # on the original workspace that the command was run on.
    set $menu ${pkgs.dmenu}/bin/dmenu_path | menu | xargs swaymsg exec --

    ### Output configuration
    #
    # Default wallpaper (more resolutions are available in @datadir@/backgrounds/sway/)
    # output * bg @datadir@/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
    #
    # Example configuration:
    #
    #   output HDMI-A-1 resolution 1920x1080 position 1920,0
    #
    # You can get the names of your outputs by running: swaymsg -t get_outputs

    ### Idle configuration
    #
    # Example configuration:
    #
    # exec swayidle -w \
    #          timeout 300 'swaylock -f -c 000000' \
    #          timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
    #          before-sleep 'swaylock -f -c 000000'
    #
    # This will lock your screen after 300 seconds of inactivity, then turn off
    # your displays after another 300 seconds, and turn your screens back on when
    # resumed. It will also lock your screen before your computer goes to sleep.

    ### Input configuration
    #
    # Example configuration:
    #
      input "2321:21128:HTIX5288:00_0911:5288_Touchpad" {
          tap enabled
      }
    #
    # You can get the names of your inputs by running: swaymsg -t get_inputs
    # Read `man 5 sway-input` for more information about this section.

    ### Key bindings
    #
    # Basics:
    #
        # Start a terminal
        bindsym $mod+Shift+Return exec $term

        # Kill focused window
        bindsym $mod+Shift+c kill

        # Start your launcher
        bindsym $mod+d exec $menu

        # Drag floating windows by holding down $mod and left mouse button.
        # Resize them with right mouse button + $mod.
        # Despite the name, also works for non-floating windows.
        # Change normal to inverse to use left mouse button for resizing and right
        # mouse button for dragging.
        floating_modifier $mod normal

        # Reload the configuration file
        bindsym $mod+Shift+r reload

        # Exit sway (logs you out of your Wayland session)
        bindsym $mod+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'
    #
    # Moving around:
    #
        # Move your focus around
        bindsym $mod+Left focus left
        bindsym $mod+Down focus down
        bindsym $mod+Up focus up
        bindsym $mod+Right focus right

        # Move the focused window with the same, but add Shift
        bindsym $mod+Shift+Left move left
        bindsym $mod+Shift+Down move down
        bindsym $mod+Shift+Up move up
        bindsym $mod+Shift+Right move right
    # Layout stuff:
    #
        # You can "split" the current object of your focus with
        # $mod+b or $mod+v, for horizontal and vertical splits
        # respectively.
        bindsym $mod+b splith
        bindsym $mod+v splitv

        # Switch the current container between different layout styles
        bindsym $mod+s layout stacking
        bindsym $mod+w layout tabbed
        bindsym $mod+e layout toggle split

        # Make the current focus fullscreen
        bindsym $mod+f fullscreen

        # Toggle the current focus between tiling and floating mode
        bindsym $mod+Shift+space floating toggle

        # Swap focus between the tiling area and the floating area
        bindsym $mod+space focus mode_toggle

        # Move focus to the parent container
        bindsym $mod+Shift+a focus parent
    #
    # Scratchpad:
    #
        # Sway has a "scratchpad", which is a bag of holding for windows.
        # You can send windows there and get them back later.

        # Move the currently focused window to the scratchpad
        bindsym $mod+Shift+minus move scratchpad

        # Show the next scratchpad window or hide the focused scratchpad window.
        # If there are multiple scratchpad windows, this command cycles through them.
        bindsym $mod+minus scratchpad show
    #
    # Resizing containers:
    #
    mode "resize" {
        # left will shrink the containers width
        # right will grow the containers width
        # up will shrink the containers height
        # down will grow the containers height
        bindsym $left resize shrink width 10px
        bindsym $down resize grow height 10px
        bindsym $up resize shrink height 10px
        bindsym $right resize grow width 10px

        # Ditto, with arrow keys
        bindsym Left resize shrink width 10px
        bindsym Down resize grow height 10px
        bindsym Up resize shrink height 10px
        bindsym Right resize grow width 10px

        # Return to default mode
        bindsym Return mode "default"
        bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    default_border pixel 1
    default_floating_border none
    smart_borders on

    bindsym $mod+q exec ${pkgs.writers.writeDash "goto_workspace" ''
      set -efux
      CURRENT_OUTPUT=$(swaymsg -r -t get_outputs | jq '.[] | select(.focused == true).name')
      WS=$(swaymsg -r -t get_workspaces |
        jq -r '.[].name' |
        menu -p 'Workspace name: '
      )
      if [ -n "$WS" ]; then
        swaymsg workspace "$WS"
        swaymsg move workspace to output "$CURRENT_OUTPUT"
      fi
    ''}

    bindsym $mod+Shift+q exec ${pkgs.writers.writeDash "moveto_workspace" ''
      set -efux
      WS=$(swaymsg -r -t get_workspaces |
        jq -r '.[].name' |
        menu -p 'Workspace name: '
      )
      if [ -n "$WS" ]; then
        swaymsg move container to workspace "$WS"
      fi
    ''}

    bindsym $mod+y exec /run/current-system/sw/bin/switch-theme toggle

    bindsym $mod+Tab focus next
    bindsym $mod+Escape workspace back_and_forth

    # screenlock
    bindsym $mod+F11 exec ${lib.getExe' pkgs.systemd "systemctl"} --user start lock.target

    # media buttons
    bindsym XF86AudioMute exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-mute @DEFAULT_SINK@ toggle
    bindsym XF86AudioRaiseVolume exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-volume @DEFAULT_SINK@ +4%
    bindsym XF86AudioLowerVolume exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-volume @DEFAULT_SINK@ -4%

    # brightness keys
    bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
    bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+

    # background programs
    exec ydotoold
    exec_always pkill kanshi; exec ${pkgs.kanshi}/bin/kanshi

    # theme and env specific stuff
    exec_always ${pkgs.writers.writeDash "dbus-sway-environment" ''
      set -efux
      dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP=sway
      systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
      systemctl --user restart --no-block sway-session.target
      systemctl --user stop xdg-desktop-portal xdg-desktop-portal-wlr
      systemctl --user start xdg-desktop-portal xdg-desktop-portal-wlr
    ''}

    exec_always ${pkgs.writers.writeDash "gsettings" ''
      set -efux
      export XDG_DATA_DIRS=${pkgs.gsettings-desktop-schemas}:$XDG_DATA_DIRS
      gnome_schema=org.gnome.desktop.interface
      gsettings set $gnome_schema gtk-theme 'Dracula'
    ''}

    # keyboard
    input type:keyboard {
      xkb_layout us
      xkb_variant altgr-intl
      xkb_options caps:hyper
    }

    # flameshot
    for_window [app_id="flameshot"] border pixel 0, floating enable, fullscreen disable, move absolute position 0 0
    exec ${pkgs.flameshot}/bin/flameshot
  '';

}
