{ config, pkgs, ... }:
{
  services.matrix-synapse = {
    enable = true;
    settings = {
      server_name = "lassul.us";
      # registration_shared_secret = "yolo";
      database.name = "sqlite3";
      turn_uris  = [
        "turn:turn.matrix.org?transport=udp"
        "turn:turn.matrix.org?transport=tcp"
      ];
      listeners = [
        {
          port = 8008;
          bind_addresses = [ "::1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [ "client" ];
              compress = true;
            }
            {
              names = [ "federation" ];
              compress = false;
            }
          ];
        }
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [ 8008 ];
}
