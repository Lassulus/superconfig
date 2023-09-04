{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."flix.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://yellow.r:8096";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
