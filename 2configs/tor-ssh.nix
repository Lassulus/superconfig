{ config, pkgs,  ... }:
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

  clanCore.secrets.tor-ssh = {
    secrets."ssh-tor.priv" = { };
    secrets."tor-hostname" = { };
    generator.path = with pkgs; [
      coreutils
      mkp224o
    ];
    generator.script = ''
      mkp224o-donna lass -n 1 -d . -q -O addr
      mv "$(cat addr)"/hs_ed25519_secret_key "$secrets"/ssh-tor.priv
      mv addr "$secrets"/tor-hostname
    '';
  };
}

