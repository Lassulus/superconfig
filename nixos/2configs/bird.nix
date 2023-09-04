{ config, ... }:

{
  config.services.bird = {
    enable = true;
    config = ''
      router id 192.168.122.1;
      protocol device {
        scan time 10;
      }
    '';
  };
}
