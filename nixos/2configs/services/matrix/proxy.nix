{ config, lib, pkgs, ... }:
{
  services.nginx = {
    virtualHosts = {
      "lassul.us" = {
        locations."= /.well-known/matrix/server".extraConfig = ''
          add_header Content-Type application/json;
          return 200 '${builtins.toJSON {
            "m.server" = "matrix.lassul.us:443";
          }}';
        '';
        locations."= /.well-known/matrix/client".extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '${builtins.toJSON {
            "m.homeserver" = { "base_url" = "https://matrix.lassul.us"; };
            "m.identity_server" = { "base_url" = "https://vector.im"; };
          }}';
        '';
      };
      "matrix.lassul.us" = {
        forceSSL = true;
        enableACME = true;
        locations."/_matrix" = {
          proxyPass = "http://orange.r:8008";
        };
      };
    };
  };
}
