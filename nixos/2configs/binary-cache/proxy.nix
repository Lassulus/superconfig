{ config, lib, pkgs, ...}:
{
  services.nginx = {
    enable = true;
    virtualHosts."cache.krebsco.de" = {
      enableACME = true;
      forceSSL = true;
      locations."/".extraConfig = ''
        proxy_pass http://cache.neoprism.r/;
      '';
    };
  };
}
