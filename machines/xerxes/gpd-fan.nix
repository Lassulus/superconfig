{ pkgs, ... }:
let
  # Find hwmon device by name and return path to specific file
  # Usage: findHwmon "k10temp" "temp1_input" -> /sys/class/hwmon/hwmonX/temp1_input
  gpd-fan-control = pkgs.writeShellScript "gpd-fan-control" ''
    set -euo pipefail

    # Configuration
    INTERVAL=2
    MINTEMP=55000   # millidegrees - fan off below this
    MAXTEMP=90000   # millidegrees - fan full above this
    MINPWM=0
    MAXPWM=255

    # Find hwmon paths by name
    find_hwmon() {
      local name=$1
      for hwmon in /sys/class/hwmon/hwmon*; do
        if [[ -f "$hwmon/name" ]] && [[ "$(cat "$hwmon/name")" == "$name" ]]; then
          echo "$hwmon"
          return 0
        fi
      done
      echo "ERROR: hwmon device '$name' not found" >&2
      return 1
    }

    FAN_HWMON=$(find_hwmon "gpdfan")
    TEMP_HWMON=$(find_hwmon "k10temp")

    PWM_FILE="$FAN_HWMON/pwm1"
    PWM_ENABLE="$FAN_HWMON/pwm1_enable"
    TEMP_FILE="$TEMP_HWMON/temp1_input"

    echo "Fan control: $PWM_FILE"
    echo "Temperature: $TEMP_FILE"

    # Enable manual PWM control
    echo 1 > "$PWM_ENABLE"

    cleanup() {
      echo "Restoring automatic fan control..."
      echo 0 > "$PWM_ENABLE" 2>/dev/null || true
    }
    trap cleanup EXIT

    while true; do
      TEMP=$(cat "$TEMP_FILE")

      if (( TEMP <= MINTEMP )); then
        PWM=$MINPWM
      elif (( TEMP >= MAXTEMP )); then
        PWM=$MAXPWM
      else
        # Linear interpolation
        PWM=$(( (TEMP - MINTEMP) * (MAXPWM - MINPWM) / (MAXTEMP - MINTEMP) + MINPWM ))
      fi

      echo "$PWM" > "$PWM_FILE"
      sleep "$INTERVAL"
    done
  '';
in
{
  boot.kernelModules = [
    "gpd_fan"
    "k10temp"
  ];

  # Disable the built-in fancontrol (it uses brittle hwmon numbers)
  hardware.fancontrol.enable = false;

  systemd.services.gpd-fan-control = {
    description = "GPD Fan Control (dynamic hwmon discovery)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      ExecStart = gpd-fan-control;
      Restart = "always";
      RestartSec = 5;
    };
  };
}
