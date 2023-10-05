{ config, lib, pkgs, ... }:
{
  imports = [
     ../../git.nix
  ];
  services.nginx.virtualHosts."cgit.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations = config.services.nginx.virtualHosts.cgit.locations;
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
