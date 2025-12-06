{
  pkgs,
  lib,
  self,
  ...
}:
let

  term = "/run/current-system/sw/bin/alacritty";

  # eww configuration
  ewwYuck = pkgs.writeText "eww.yuck" ''
    ; Variables with polling - set initial values to avoid empty string errors
    (defpoll time :interval "1s" :initial "00:00" "date '+%H:%M'")
    (defpoll date :interval "60s" :initial "0000-00-00" "date '+%Y-%m-%d'")
    (defpoll cpu :interval "2s" :initial 0 "${lib.getExe cpuScript}")
    (defpoll memory :interval "2s" :initial 0 "${lib.getExe memScript}")
    (defpoll temperature :interval "2s" :initial 0 "${lib.getExe tempScript}")
    (defpoll battery :interval "10s" :initial '{"capacity": "100", "icon": "󰁹", "watts": "0", "time_remaining": "--", "status": "Full"}' "${lib.getExe batteryScript}")
    (defpoll volume :interval "1s" :initial '{"level": "0", "icon": "󰕿"}' "${lib.getExe volumeScript}")
    (defpoll network :interval "5s" :initial "󰖪 ..." "${lib.getExe networkScript}")
    (deflisten workspaces :initial '[]' "${lib.getExe workspacesScript}")

    ; Widget definitions
    (defwidget bar []
      (centerbox :orientation "h"
        (left)
        (center)
        (right)))

    (defwidget left []
      (box :class "left" :orientation "h" :space-evenly false :halign "start"
        (workspaces-widget)))

    (defwidget center []
      (box :class "center" :orientation "h" :space-evenly false :halign "center"
        (label :text "''${time}")))

    (defwidget right []
      (box :class "right" :orientation "h" :space-evenly false :halign "end" :spacing 8
        (network-widget)
        (volume-widget)
        (graph-widget :value cpu :icon "󰍛" :class "cpu" :unit "%")
        (graph-widget :value memory :icon "󰘚" :class "memory" :unit "%")
        (graph-widget :value temperature :icon "󰔏" :class "temp" :unit "°")
        (battery-widget)
        (label :class "date" :text "''${date}")
        (systray :class "systray" :icon-size 18 :spacing 4)))

    (defwidget workspaces-widget []
      (box :class "workspaces" :orientation "h" :space-evenly false :spacing 0
        (for ws in workspaces
          (button :class {ws.urgent ? "workspace urgent" : (ws.focused ? "workspace focused" : "workspace")}
                  :onclick "swaymsg workspace ''${ws.name}"
            {ws.name}))))

    (defwidget graph-widget [value icon class unit]
      (box :class "graph-module ''${class}" :orientation "h" :space-evenly false :spacing 4
        (graph :class "graph"
               :value value
               :thickness 3
               :time-range "60s"
               :min 0
               :max 100
               :dynamic true
               :line-style "round"
               :width 75)
        (label :text "''${value}''${unit} ''${icon}")))

    (defwidget battery-widget []
      (box :class "battery" :orientation "h" :space-evenly false
           :tooltip "''${battery.watts}W | ''${battery.time_remaining} ''${battery.status == 'Charging' ? 'to full' : 'remaining'}"
        (label :text "''${battery.capacity}% ''${battery.icon}")))

    (defwidget volume-widget []
      (box :class "volume" :orientation "h" :space-evenly false
        (label :text "''${volume.level}% ''${volume.icon}")))

    (defwidget network-widget []
      (box :class "network" :orientation "h" :space-evenly false
        (label :text "''${network}")))

    ; Window definition - screen name passed as argument
    (defwindow bar [screen]
      :monitor screen
      :geometry (geometry :x "0%"
                          :y "0%"
                          :width "100%"
                          :height "36px"
                          :anchor "top center")
      :stacking "fg"
      :exclusive true
      :focusable false
      (bar))
  '';

  ewwScss = pkgs.writeText "eww.scss" ''
    * {
      all: unset;
      font-family: "Iosevka Nerd Font", monospace;
      font-size: 14px;
    }

    window {
      background-color: #1a1b26;
      color: #c0caf5;
    }

    .left, .center, .right {
      margin: 4px 8px;
    }

    .workspaces {
      button {
        padding: 0 4px;
        margin: 0 1px;
        border-radius: 2px;
        min-width: 24px;
        background-color: #24283b;
        &.focused {
          background-color: #7aa2f7;
          color: #1a1b26;
        }
        &.urgent {
          background-color: #f7768e;
          color: #1a1b26;
        }
        &:hover {
          background-color: #414868;
        }
      }
    }

    .graph-module {
      padding: 0 8px;
      margin: 0 2px;
      border-radius: 4px;
      &.cpu {
        background-color: #9ece6a;
        color: #1a1b26;
      }
      &.memory {
        background-color: #7dcfff;
        color: #1a1b26;
      }
      &.temp {
        background-color: #ff9e64;
        color: #1a1b26;
      }
    }

    .graph {
      min-height: 20px;
    }

    .battery, .volume, .network, .date {
      padding: 0 8px;
      margin: 0 2px;
      border-radius: 4px;
      background-color: #24283b;
    }

    .systray {
      padding: 0 8px;
      margin: 0 2px;
    }

    tooltip {
      background-color: #1a1b26;
      color: #c0caf5;
      border: 1px solid #414868;
      border-radius: 4px;
      padding: 4px 8px;
    }
  '';

  cpuScript = pkgs.writeShellApplication {
    name = "eww-cpu";
    text = ''
      STATE_FILE="/tmp/eww-cpu-state"
      read -r _cpu user nice system idle _rest < /proc/stat
      total=$((user + nice + system + idle))

      if [ -f "$STATE_FILE" ]; then
        read -r prev_total prev_idle < "$STATE_FILE"
        diff_total=$((total - prev_total))
        diff_idle=$((idle - prev_idle))
        if [ "$diff_total" -gt 0 ]; then
          echo $((100 * (diff_total - diff_idle) / diff_total))
        else
          echo 0
        fi
      else
        echo 0
      fi
      echo "$total $idle" > "$STATE_FILE"
    '';
  };

  memScript = pkgs.writeShellApplication {
    name = "eww-mem";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {printf "%d", (total-available)*100/total}' /proc/meminfo
    '';
  };

  tempScript = pkgs.writeShellApplication {
    name = "eww-temp";
    text = ''
      temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
      echo $((temp_raw / 1000))
    '';
  };

  batteryScript = pkgs.writeShellApplication {
    name = "eww-battery";
    runtimeInputs = [
      pkgs.jq
      pkgs.bc
    ];
    text = ''
      # Find battery device dynamically
      bat_path=""
      for p in /sys/class/power_supply/BAT* /sys/class/power_supply/BATT*; do
        if [ -f "$p/capacity" ]; then
          bat_path="$p"
          break
        fi
      done

      if [ -z "$bat_path" ]; then
        echo '{"capacity": "N/A", "icon": "󰂃", "watts": "0", "time_remaining": "N/A"}'
        exit 0
      fi

      capacity=$(cat "$bat_path/capacity" 2>/dev/null || echo 100)
      status=$(cat "$bat_path/status" 2>/dev/null || echo "Full")
      power_now=$(cat "$bat_path/power_now" 2>/dev/null || echo 0)
      energy_now=$(cat "$bat_path/energy_now" 2>/dev/null || echo 0)
      energy_full=$(cat "$bat_path/energy_full" 2>/dev/null || echo 0)

      # Convert microwatts to watts
      watts=$(echo "scale=1; $power_now / 1000000" | bc)

      # Calculate time remaining
      if [ "$power_now" -gt 0 ]; then
        if [ "$status" = "Charging" ]; then
          # Time to full
          remaining_energy=$((energy_full - energy_now))
          hours=$(echo "scale=2; $remaining_energy / $power_now" | bc)
        else
          # Time to empty
          hours=$(echo "scale=2; $energy_now / $power_now" | bc)
        fi
        # Convert to hours:minutes
        h=$(echo "$hours" | cut -d. -f1)
        m=$(echo "scale=0; ($hours - $h) * 60 / 1" | bc)
        time_remaining="''${h}h ''${m}m"
      else
        time_remaining="--"
      fi

      if [ "$status" = "Charging" ]; then
        icon="󰂄"
      elif [ "$status" = "Full" ]; then
        icon="󰁹"
      elif [ "$capacity" -gt 80 ]; then
        icon="󰂂"
      elif [ "$capacity" -gt 60 ]; then
        icon="󰂀"
      elif [ "$capacity" -gt 40 ]; then
        icon="󰁾"
      elif [ "$capacity" -gt 20 ]; then
        icon="󰁼"
      else
        icon="󰁺"
      fi
      jq -n --arg cap "$capacity" --arg icon "$icon" --arg watts "$watts" --arg time "$time_remaining" --arg status "$status" \
        '{capacity: $cap, icon: $icon, watts: $watts, time_remaining: $time, status: $status}'
    '';
  };

  volumeScript = pkgs.writeShellApplication {
    name = "eww-volume";
    runtimeInputs = [
      pkgs.pulseaudio
      pkgs.jq
      pkgs.gnugrep
    ];
    text = ''
      vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%')
      muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(yes|no)')
      if [ "$muted" = "yes" ]; then
        icon="󰖁"
      elif [ "$vol" -gt 50 ]; then
        icon="󰕾"
      elif [ "$vol" -gt 0 ]; then
        icon="󰖀"
      else
        icon="󰕿"
      fi
      jq -n --arg level "$vol" --arg icon "$icon" '{level: $level, icon: $icon}'
    '';
  };

  networkScript = pkgs.writeShellApplication {
    name = "eww-network";
    runtimeInputs = [ pkgs.networkmanager ];
    text = ''
      connection=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | head -1)
      if [ -z "$connection" ]; then
        echo "󰖪 Disconnected"
      else
        name=$(echo "$connection" | cut -d: -f1)
        type=$(echo "$connection" | cut -d: -f2)
        if [ "$type" = "802-11-wireless" ]; then
          echo "󰖩 $name"
        else
          echo "󰈀 $name"
        fi
      fi
    '';
  };

  workspacesScript = pkgs.writeShellApplication {
    name = "sway-workspaces";
    runtimeInputs = [
      pkgs.sway
      pkgs.jq
    ];
    text = ''
      # Output initial state
      swaymsg -t get_workspaces | jq -c '[.[] | {name: .name, focused: .focused, urgent: .urgent}]'

      # Subscribe to workspace events and output updated state
      swaymsg -t subscribe -m '["workspace"]' | while read -r _; do
        swaymsg -t get_workspaces | jq -c '[.[] | {name: .name, focused: .focused, urgent: .urgent}]'
      done
    '';
  };

  ewwConfigDir = pkgs.runCommand "eww-config" { } ''
    mkdir -p $out
    cp ${ewwYuck} $out/eww.yuck
    cp ${ewwScss} $out/eww.scss
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

  # Enable realtime scheduling for sway
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = 1;
    }
  ];

  # eww daemon
  systemd.user.services.eww = {
    description = "ElKowars Wacky Widgets daemon";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    path = [
      pkgs.bash
      pkgs.sway
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.eww}/bin/eww daemon --config ${ewwConfigDir} --no-daemonize";
      ExecStop = "${pkgs.eww}/bin/eww --config ${ewwConfigDir} kill";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # eww bar per output - template unit using output name (e.g. eww-bar@eDP-1.service)
  systemd.user.services."eww-bar@" = {
    description = "Eww bar on output %i";
    partOf = [ "sway-session.target" ];
    after = [ "eww.service" ];
    requires = [ "eww.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.eww}/bin/eww --config ${ewwConfigDir} open bar --id bar-%i --arg screen=%i";
      ExecStop = "${pkgs.eww}/bin/eww --config ${ewwConfigDir} close bar-%i";
    };
  };

  # Watches for output changes and starts/stops eww-bar@ instances
  systemd.user.services.eww-output-watcher = {
    description = "Watch for output changes and manage eww bars";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    after = [ "eww.service" ];
    requires = [ "eww.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "eww-output-watcher";
          runtimeInputs = [
            pkgs.sway
            pkgs.jq
            pkgs.systemd
            pkgs.gawk
            pkgs.gnused
            pkgs.gnugrep
          ];
          text = ''
            update_bars() {
              # Get current outputs
              outputs=$(swaymsg -t get_outputs | jq -r '.[].name')

              # Start bars for connected outputs
              for output in $outputs; do
                systemctl --user start "eww-bar@$output.service" || true
              done

              # Stop bars for disconnected outputs
              running=$(systemctl --user list-units --type=service --state=running --plain --no-legend 'eww-bar@*' | awk '{print $1}' | sed 's/eww-bar@\(.*\)\.service/\1/')
              for output in $running; do
                if ! echo "$outputs" | grep -qx "$output"; then
                  systemctl --user stop "eww-bar@$output.service" || true
                fi
              done
            }

            update_bars
            swaymsg -t subscribe -m '["output"]' | while read -r _; do
              sleep 0.5
              update_bars
            done
          '';
        }
      );
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.user.services.sway-urgent-rumble = {
    description = "Trigger rumble on urgent windows";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    unitConfig = {
      ConditionPathExists = [
        "/dev/input/event2"
        "/sys/class/input/event2/device/capabilities/ff"
      ];
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "sway-urgent-rumble";
          runtimeInputs = [
            pkgs.sway
            pkgs.jq
            self.packages.${pkgs.system}.gpd-rumble
          ];
          text = ''
            swaymsg -t subscribe -m '["window"]' | \
            jq --unbuffered -r 'select(.change == "urgent" and .container.urgent == true) | "urgent"' | \
            while read -r _; do
              gpd-rumble 200 100 &
            done
          '';
        }
      );
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

    # Focus primary output
    bindsym $mod+F1 exec ${
      lib.getExe (
        pkgs.writeShellApplication {
          name = "focus-primary-output";
          runtimeInputs = [
            pkgs.sway
            pkgs.jq
          ];
          text = ''
            PRIMARY=$(swaymsg -r -t get_outputs | jq -r 'sort_by(.x, .y) | .[0].name')
            swaymsg focus output "$PRIMARY"
          '';
        }
      )
    }

    # Cycle through secondary outputs
    bindsym $mod+F2 exec ${
      lib.getExe (
        pkgs.writeShellApplication {
          name = "cycle-secondary-outputs";
          runtimeInputs = [
            pkgs.sway
            pkgs.jq
            pkgs.gnugrep
            pkgs.coreutils
          ];
          text = ''
            OUTPUTS=$(swaymsg -r -t get_outputs | jq -r 'sort_by(.x, .y)')
            PRIMARY=$(echo "$OUTPUTS" | jq -r '.[0].name')
            CURRENT=$(echo "$OUTPUTS" | jq -r '.[] | select(.focused == true).name')
            SECONDARIES=$(echo "$OUTPUTS" | jq -r '.[1:] | .[].name')

            if [ -z "$SECONDARIES" ]; then
              exit 0
            fi

            if [ "$CURRENT" = "$PRIMARY" ]; then
              # Focus first secondary
              NEXT=$(echo "$SECONDARIES" | head -n1)
            else
              # Find next secondary in the list
              NEXT=$(echo "$SECONDARIES" | grep -A1 "^$CURRENT$" | tail -n1)
              # If we're at the end, wrap to first secondary
              if [ "$NEXT" = "$CURRENT" ]; then
                NEXT=$(echo "$SECONDARIES" | head -n1)
              fi
            fi

            swaymsg focus output "$NEXT"
          '';
        }
      )
    }

    # screenlock
    bindsym $mod+F11 exec ${lib.getExe' pkgs.systemd "systemctl"} --user start lock.target

    # kill window (xkill-like)
    mode "kill" {
        bindsym --whole-window button1 kill, mode "default"
        bindsym --whole-window button2 mode "default"
        bindsym --whole-window button3 mode "default"
        bindsym Escape mode "default"
    }
    bindsym $mod+x mode "kill"

    # media buttons
    bindsym XF86AudioMute exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-mute @DEFAULT_SINK@ toggle
    bindsym XF86AudioRaiseVolume exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-volume @DEFAULT_SINK@ +4%
    bindsym XF86AudioLowerVolume exec ${pkgs.pulseaudio.out}/bin/pactl -- set-sink-volume @DEFAULT_SINK@ -4%

    # brightness keys
    bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
    bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+

    # background programs
    exec ${pkgs.copyq}/bin/copyq --start-server
    exec ydotoold
    exec_always pkill kanshi; exec ${pkgs.kanshi}/bin/kanshi
    exec_always pkill swayidle; exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout 120 '${lib.getExe' pkgs.systemd "systemctl"} --user start lock.target' \
      timeout 300 '${lib.getExe' pkgs.systemd "systemctl"} suspend' \
      before-sleep '${lib.getExe' pkgs.systemd "systemctl"} --user start lock.target'
    exec_always pkill sway-audio-idle-inhibit; exec ${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit

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
