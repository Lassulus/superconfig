{ ... }:
{
  services.nginx.virtualHosts."mergebot.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://ignavia.r:8081";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
      '';
    };
  };
}
