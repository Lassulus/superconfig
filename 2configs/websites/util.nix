{ lib, ... }:

with lib;

{
  servePage =
    domains:
    let
      domain = head domains;
    in
    {
      services.nginx.virtualHosts.${domain} = {
        enableACME = true;
        addSSL = true;
        serverAliases = domains;
        locations."/".extraConfig = ''
          root /srv/http/${domain};
        '';
      };
    };
}
