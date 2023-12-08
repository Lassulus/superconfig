{ config, ... }:
{
  services.changedetection-io = {
    enable = true;
    behindProxy = true;
  };

  services.nginx.virtualHosts."cdio.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://localhost:${toString config.services.changedetection-io.port}";
  };
}
