{
  services.nginx.virtualHosts."hass.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "http://styx.n:8123";
    };
  };
}
