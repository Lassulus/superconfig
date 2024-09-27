{ config, ... }: {
  services.owncast.enable = true;
  services.owncast.port = 8081;
  services.nginx = {
    enable = true;
    virtualHosts."cast.lassul.us" = {
      enableACME = true;
      forceSSL = true;
      locations."/".extraConfig = ''
        proxy_pass http://localhost:${toString config.services.owncast.port};
      '';
    };
  };
  networking.firewall.allowedTCPPorts = [ config.services.owncast.rtmp-port ];
}
