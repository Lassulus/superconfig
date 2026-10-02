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
      secretKey = config.clan.core.vars.generators.tor-ssh.files."hs_ed25519_secret_key".path;
    };
    controlSocket.enable = true;
    client.enable = true;
  };

  clan.core.vars.generators.tor-ssh = {
    files."hs_ed25519_secret_key" = { };
    files."hostname".deploy = false;
    runtimeInputs = with pkgs; [
      coreutils
      tor
    ];
    script = ''
      mkdir -p data
      echo -e "DataDirectory ./data\nSocksPort 0\nHiddenServiceDir ./hs\nHiddenServicePort 80 127.0.0.1:80" > torrc
      timeout 2 tor -f torrc || :
      mv hs/hs_ed25519_secret_key $out/hs_ed25519_secret_key
      mv hs/hostname $out/hostname
    '';
  };
}
