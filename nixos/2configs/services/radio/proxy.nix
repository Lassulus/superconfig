{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."radio.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      # recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "http://radio.r";
      extraConfig = ''
        proxy_set_header Host radio.r;
        # get source ip for weather reports
        proxy_set_header user-agent "$http_user_agent; client-ip=$remote_addr";
      '';
    };
  };
}
