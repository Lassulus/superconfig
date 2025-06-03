{ config, pkgs, ... }:
{
  services.tor = {
    enable = true;
    relay.onionServices.ssh = {
      version = 3;
      map = [
        {
          port = 22;
          target.port = 22;
        }
      ];
      secretKey = config.clan.core.vars.generators.tor-ssh.files."ssh-tor.priv".path;
    };
    controlSocket.enable = true;
    client.enable = true;
  };

  clan.core.vars.generators.tor-ssh = {
    files."ssh-tor.priv" = { };
    files."tor-hostname".deploy = false;
    migrateFact = "tor-ssh";
    runtimeInputs = with pkgs; [
      coreutils
      mkp224o
    ];
    script = ''
      mkp224o-donna lass -n 1 -d . -q -O addr
      mv "$(cat addr)"/hs_ed25519_secret_key "$out"/ssh-tor.priv
      mv addr "$out"/tor-hostname
    '';
  };
}
