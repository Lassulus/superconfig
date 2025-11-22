{
  _class = "clan.service";
  manifest.name = "tor";
  manifest.description = "tor networking between hosts";
  manifest.categories = [ "networking" ];
  roles.default = {
    # interface =
    #   { lib, ... }:
    #   {
    #     options = {
    #       OciSettings = lib.mkOption {
    #         type = lib.types.raw;
    #         default = null;
    #         description = "NixOS settings for virtualisation.oci-container.<name>.settings";
    #       };
    #       buildContainer = lib.mkOption {
    #         type = lib.types.nullOr lib.types.str;
    #         default = null;
    #       };
    #     };
    #   };
    perInstance =
      {
        instanceName,
        roles,
        lib,
        ...
      }:
      {
        # nix run .#clan.inventory.instances.<instanceName>.actions.build-docker-container
        exports.networking = {
          priority = lib.mkDefault 10;
          # TODO add user space network support to clan-cli
          technology = "tor";
          peers = lib.mapAttrs (name: _machine: {
            host.var = {
              machine = name;
              generator = "tor-ssh";
              file = "hostname";
            };
          }) roles.default.machines;
        };
        nixosModule =
          {
            pkgs,
            config,
            ...
          }:
          {
            config = {
              services.tor = {
                enable = true;
                relay.onionServices."clan_${instanceName}" = {
                  version = 3;
                  # TODO get ports from instance machine config
                  map = [
                    {
                      port = 22;
                      target.port = 22;
                    }
                  ];
                  secretKey = config.clan.core.vars.generators."tor_${instanceName}".files.hs_ed25519_secret_key.path;
                };
              };
              clan.core.vars.generators."tor_${instanceName}" = {
                files.hs_ed25519_secret_key = { };
                files.hostname = { };
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
            };
          };
      };
  };
}
