{ pkgs, ... }:

let
  # Script that monitors upower D-Bus signals and speaks when battery gets low
  batteryMonitor = pkgs.writers.writeBash "battery-monitor" ''
    ${pkgs.upower}/bin/upower --monitor-detail | while read -r line; do
      if echo "$line" | grep -q "warning-level:.*low"; then
        ${pkgs.espeak}/bin/espeak -v +whisper -s 110 "power level low"
      fi
    done
  '';

in
{
  # UPower handles battery monitoring via kernel events (not polling)
  services.upower = {
    enable = true;

    # Use percentage thresholds instead of time-based
    usePercentageForPolicy = true;

    # Warning levels (triggers D-Bus signals for our monitor)
    percentageLow = 15;
    percentageCritical = 10;

    # Suspend when battery drops below this
    percentageAction = 5;

    # Action to take at critical level
    criticalPowerAction = "Suspend";
    allowRiskyCriticalPowerAction = true;
  };

  # User service to monitor battery and speak warnings
  systemd.user.services.battery-warning = {
    description = "Battery low warning speaker";
    wantedBy = [ "default.target" ];
    after = [ "upower.service" ];

    serviceConfig = {
      ExecStart = batteryMonitor;
      Restart = "always";
      RestartSec = 5;
    };
  };
}
