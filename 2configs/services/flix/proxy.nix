{ pkgs, ... }:
{
  services.nginx.virtualHosts."flix.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://yellow.r:8096";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
  services.nginx.virtualHosts."flex.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://radar.r:7878";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        auth_basic "Restricted Content";
        auth_basic_user_file ${pkgs.writeText "flix-user-pass" ''
          krebs:$apr1$1Fwt/4T0$YwcUn3OBmtmsGiEPlYWyq0
        ''};
      '';
    };
  };
  services.nginx.virtualHosts."flux.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://sonar.r:8989";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        auth_basic "Restricted Content";
        auth_basic_user_file ${pkgs.writeText "flix-user-pass" ''
          krebs:$apr1$1Fwt/4T0$YwcUn3OBmtmsGiEPlYWyq0
        ''};
      '';
    };
  };
}
