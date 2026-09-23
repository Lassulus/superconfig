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

  # One address may hold a household's worth of tabs and join at a human
  # pace. Without this a single host opened ~2500 sockets at once and churned
  # thousands more, and the thread-per-socket server ran out of tasks for
  # everyone else.
  services.nginx.appendHttpConfig = ''
    limit_conn_zone $binary_remote_addr zone=mazegame_conns:10m;
    limit_req_zone $binary_remote_addr zone=mazegame_joins:10m rate=2r/s;
  '';

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    # nginx hands out the client straight from the store — the very package
    # the service runs, so the page never lags the server. The game is a
    # single event loop: every .js it serves during a join burst is a tick it
    # is not spending on the world, and a crowd arriving costs six files each.
    root = config.services.mazegame.package.static;
    locations."/" = {
      index = "index.html";
      tryFiles = "$uri $uri/ =404";
      # Versions ride in the store path but the URLs never change, so let the
      # browser revalidate against the ETag rather than cache a stale client.
      # add_header does not inherit into the exact-match locations below.
      extraConfig = ''add_header Cache-Control "no-cache";'';
    };
    locations."= /play" = {
      tryFiles = "/index.html =404";
      extraConfig = ''add_header Cache-Control "no-cache";'';
    };
    locations."= /watch" = {
      tryFiles = "/watch.html =404";
      extraConfig = ''add_header Cache-Control "no-cache";'';
    };

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
        limit_conn mazegame_conns 32;
        limit_req zone=mazegame_joins burst=30 nodelay;
        limit_conn_status 429;
        limit_req_status 429;
      '';
    };
    locations."/api/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
    };
  };
}
