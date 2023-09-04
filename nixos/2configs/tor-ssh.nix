{ config, ... }:
{
  services.tor = {
    enable = true;
    relay.onionServices.ssh = {
      version = 3;
      map = [{
        port = 22;
        target.port = 22;
      }];
      secretKey = "${config.krebs.secret.directory}/ssh-tor.priv";
    };
    controlSocket.enable = true;
    client.enable = true;
  };
}

