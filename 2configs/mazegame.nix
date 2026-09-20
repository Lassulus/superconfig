let
  domain = "maze.lassul.us";
  port = 8772;
in
{ self, config, ... }:
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
    # nginx hands out the client straight from the store. The game server is a
    # single event loop: every .js it serves during a join burst is time it is
    # not spending on the world tick, and a crowd arriving costs six files
    # each.
    # …the very package the service runs, so the client never lags the server.
    root = config.services.mazegame.package.static;
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ =404";
      extraConfig = ''
        # Versions ride in the store path, but the URLs never change, so let
        # the browser revalidate rather than cache a stale client.
        add_header Cache-Control "no-cache";
      '';
    };
    locations."= /play".tryFiles = "/index.html =404";
    locations."= /watch".tryFiles = "/watch.html =404";

    # Player and watcher sockets stay open for as long as someone is in the
    # maze; players heartbeat every 3s, watchers every 3s, so the default
    # 60s read timeout would only bite on a wedged client, but a long window
    # keeps idle spectators connected.
    locations."/ws/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
    locations."/api/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
    };
  };
}
