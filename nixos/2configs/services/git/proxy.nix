{ config, pkgs, ... }:
{
  services.nginx.virtualHosts."cgit.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    acmeFallbackHost = "orange.r";
    locations."/" = {
      proxyPass = "http://orange.r";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    extraConfig = ''
      client_max_body_size 300M;
      client_body_timeout 2024;
      client_header_timeout 2024;

      fastcgi_buffers 16 512k;
      fastcgi_buffer_size 512k;
      fastcgi_read_timeout 500;
      fastcgi_send_timeout 500;
    '';
  };
}
