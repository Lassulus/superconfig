{... }: {
  services.nginx.virtualHosts."mergebot.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://ignavia.r:8081";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
