{
  pkgs,
  lib,
  ...
}:
let

  # eww configuration
  ewwYuck = pkgs.writeText "eww.yuck" ''
    ; Magic variables (built-in, no polling needed)
    ; EWW_TIME provides current time
    ; EWW_CPU provides {cores: [...], avg: X}
    ; EWW_RAM provides {used_mem_perc: X, available_mem: Y, total_mem: Z, ...}

    ; Custom variables with polling
    (defpoll cpu-freq :interval "2s" :initial 0 "${lib.getExe cpuFreqScript}")
    (defpoll cpu-load :interval "2s" :initial "0.00" "cut -d' ' -f1 /proc/loadavg")
    (defpoll temperature :interval "2s" :initial '{"temp": 0, "fan": 0}' "${lib.getExe tempScript}")
    (defpoll battery :interval "10s" :initial '{"capacity": "100", "icon": "󰁹", "watts": "0", "time_remaining": "--", "status": "Full"}' "${lib.getExe batteryScript}")
    (defpoll volume :interval "1s" :initial '{"level": "0", "icon": "󰕿"}' "${lib.getExe volumeScript}")
    (defpoll network :interval "5s" :initial "󰖪 ..." "${lib.getExe networkScript}")
    (defpoll brightness :interval "1s" :initial 100 "${lib.getExe brightnessScript}")
    (defpoll idle-inhibited :interval "0.5s" :initial "false" "${lib.getExe idleStatusScript}")
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
        (label :text {formattime(EWW_TIME, "%H:%M")})))

    (defwidget right []
      (box :class "right" :orientation "h" :space-evenly false :halign "end" :spacing 8
        (network-widget)
        (volume-widget)
        (graph-widget :value {EWW_CPU.avg} :icon "󰍛" :class "cpu" :unit "%" :tooltip "Load: ''${cpu-load} | ''${cpu-freq} MHz")
        (graph-widget :value {EWW_RAM.used_mem_perc} :icon "󰘚" :class "memory" :unit "%")
        (graph-widget :value {temperature.temp} :icon "󰔏" :class "temp" :unit "°" :tooltip "Fan: ''${temperature.fan} RPM")
        (brightness-widget)
        (battery-widget)
        (idle-inhibitor)
        (label :class "date" :text {formattime(EWW_TIME, "%Y-%m-%d")})
        (systray :class "systray" :icon-size 18 :spacing 4)))

    (defwidget workspaces-widget []
      (box :class "workspaces" :orientation "h" :space-evenly false :spacing 0
        (for ws in workspaces
          (button :class {ws.urgent ? "workspace urgent" : (ws.focused ? "workspace focused" : "workspace")}
                  :onclick "swaymsg workspace ''${ws.name}"
            {ws.name}))))

    (defwidget graph-widget [value icon class unit ?tooltip]
      (box :class "graph-module ''${class}" :orientation "h" :space-evenly false :spacing 4
           :tooltip {tooltip ?: ""}
        (graph :class "graph"
               :value value
               :thickness 3
               :time-range "60s"
               :min 0
               :max 100
               :dynamic true
               :line-style "round"
               :width 75)
        (label :text "''${round(value, 0)}''${unit} ''${icon}")))

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

    (defwidget brightness-widget []
      (button :class "brightness" :onclick "/run/current-system/sw/bin/switch-theme toggle"
        (label :text "''${brightness}% 󰃟")))

    (defwidget idle-inhibitor []
      (button :class {idle-inhibited == "true" ? "idle-inhibitor active" : "idle-inhibitor"}
              :onclick "${lib.getExe idleToggleScript}"
        {idle-inhibited == "true" ? "󰅶" : "󰾪"}))

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

    .battery, .volume, .network, .date, .brightness {
      padding: 0 8px;
      margin: 0 2px;
      border-radius: 4px;
      background-color: #24283b;
    }

    .idle-inhibitor {
      padding: 0 8px;
      margin: 0 2px;
      border-radius: 4px;
      background-color: #24283b;
      &.active {
        background-color: #bb9af7;
        color: #1a1b26;
      }
      &:hover {
        background-color: #414868;
      }
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

  cpuFreqScript = pkgs.writeShellApplication {
    name = "eww-cpu-freq";
    runtimeInputs = [ ];
    text = ''
      # Get average CPU frequency in MHz
      freq=0
      count=0
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [ -f "$f" ]; then
          val=$(cat "$f")
          freq=$((freq + val))
          count=$((count + 1))
        fi
      done
      if [ "$count" -gt 0 ]; then
        freq=$((freq / count / 1000))
      fi
      echo "$freq"
    '';
  };

  tempScript = pkgs.writeShellApplication {
    name = "eww-temp";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
      temp=$((temp_raw / 1000))

      # Find gpdfan hwmon for fan speed
      fan=0
      for hwmon in /sys/class/hwmon/hwmon*; do
        if [ "$(cat "$hwmon/name" 2>/dev/null)" = "gpdfan" ]; then
          fan=$(cat "$hwmon/fan1_input" 2>/dev/null || echo 0)
          break
        fi
      done

      jq -n --argjson temp "$temp" --argjson fan "$fan" '{temp: $temp, fan: $fan}'
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

  brightnessScript = pkgs.writeShellApplication {
    name = "eww-brightness";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = ''
      brightnessctl -m | cut -d, -f4 | tr -d '%'
    '';
  };

  idleToggleScript = pkgs.writeShellApplication {
    name = "eww-idle-toggle";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if systemctl --user is-active --quiet sway-idle-inhibit.service; then
        systemctl --user stop sway-idle-inhibit.service
      else
        systemctl --user start sway-idle-inhibit.service
      fi
    '';
  };

  idleStatusScript = pkgs.writeShellApplication {
    name = "eww-idle-status";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if systemctl --user is-active --quiet sway-idle-inhibit.service; then
        echo "true"
      else
        echo "false"
      fi
    '';
  };

  ewwConfigDir = pkgs.runCommand "eww-config" { } ''
    mkdir -p $out
    cp ${ewwYuck} $out/eww.yuck
    cp ${ewwScss} $out/eww.scss
  '';

in
{
  # eww daemon
  systemd.user.services.eww = {
    description = "ElKowars Wacky Widgets daemon";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    path = [
      pkgs.bash
      pkgs.sway
    ];
    environment.EWW_CONFIG = "${ewwConfigDir}";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.eww} daemon --config ${ewwConfigDir} --no-daemonize";
      ExecStop = "${lib.getExe pkgs.eww} --config ${ewwConfigDir} kill";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Idle inhibit service - toggled by eww button
  systemd.user.services.sway-idle-inhibit = {
    description = "Inhibit idle/sleep";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --who=eww --why='User requested' --mode=block sleep infinity";
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
}
