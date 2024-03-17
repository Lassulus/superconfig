{ pkgs, ... }:
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
  krebs.htgen.radio-redirect = {
    port = 8000;
    scriptFile = pkgs.writers.writeDash "redir" ''
      printf 'HTTP/1.1 301 Moved Permanently\r\n'
      printf "Location: http://radio.lassul.us''${Request_URI}\r\n"
      printf '\r\n'
    '';
  };
  networking.firewall.allowedTCPPorts = [ 8000 ];
}
