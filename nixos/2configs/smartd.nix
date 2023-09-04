{ config, pkgs, ... }:

{
  services.smartd = {
    enable = true;
    devices = [
      {
        device = "DEVICESCAN";
        options = toString [
          "-a"
          "-m ${config.krebs.users.lass.mail}"
          "-s (O/../.././09|S/../.././04|L/../../6/05)"
        ];
      }
    ];
  };
}
