{ config, lib, ... }:

{
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    enableReload = true;

    virtualHosts.default = {
      locations."= /etc/os-release".extraConfig = ''
        default_type text/plain;
        alias /etc/os-release;
      '';
    };
  };
}

