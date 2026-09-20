let
  domain = "maze.lassul.us";
  port = 8772;
in
{ self, ... }:
{
  # mazegame: Windows 95 "Maze" screensaver you can play in a browser tab. The
  # exit is the NixOS snowflake. /watch is a spectator camera that follows a
  # random player and cuts to the next one after 2s without movement.
  imports = [ self.inputs.mazegame.nixosModules.default ];

  services.mazegame = {
    enable = true;
    host = "127.0.0.1";
    port = port;
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    # Player and watcher sockets stay open for as long as someone is in the
    # maze; players heartbeat every 3s, watchers every 3s, so the default
    # 60s read timeout would only bite on a wedged client, but a long window
    # keeps idle spectators connected.
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
  };
}
