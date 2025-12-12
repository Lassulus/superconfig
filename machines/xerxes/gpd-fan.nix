{
  # Load modules in explicit order for stable hwmon numbering
  # gpd_fan -> hwmon2, k10temp -> hwmon3 (loaded before ACPI devices)
  boot.kernelModules = [
    "gpd_fan"
    "k10temp"
  ];

  hardware.fancontrol = {
    enable = true;
    config = ''
      INTERVAL=2
      DEVPATH=hwmon2=devices/platform/gpd_fan hwmon3=devices/pci0000:00/0000:00:18.3
      DEVNAME=hwmon2=gpdfan hwmon3=k10temp
      FCTEMPS=hwmon2/pwm1=hwmon3/temp1_input
      FCFANS=hwmon2/pwm1=hwmon2/fan1_input
      MINTEMP=hwmon2/pwm1=45
      MAXTEMP=hwmon2/pwm1=85
      MINSTART=hwmon2/pwm1=40
      MINSTOP=hwmon2/pwm1=30
      MINPWM=hwmon2/pwm1=0
      MAXPWM=hwmon2/pwm1=255
    '';
  };
}
