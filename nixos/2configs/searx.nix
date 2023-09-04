{ pkgs, ... }:
let
  port = 8889;
in {
  services.nginx.virtualHosts.search = {
    serverAliases = [ "search.r" ];
    locations."/".extraConfig = ''
      proxy_set_header Host $host;
      proxy_pass http://127.0.0.1:${builtins.toString port};
    '';
  };

  services.searx = {
    enable = true;
    configFile = pkgs.writeText "searx.cfg" (builtins.toJSON {
      use_default_settings = true;
      server = {
        port = port;
      };
    });
  };
}
