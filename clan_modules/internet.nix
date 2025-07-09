{
  _class = "clan.service";
  manifest.name = "internet";
  manifest.description = "direct access (or via ssh jumphost) to server";
  manifest.categories = [ "networking" ];
  roles.default = {
    interface =
      { lib, ... }:
      {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            description = ''
              ip address or hostname (domain) of the machine
            '';
          };
          jumphosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              optional list of jumphosts to use to connect to the machine
            '';
          };
        };
      };
    perInstance =
      {
        roles,
        lib,
        settings,
        ...
      }:
      {
        # nix run .#clan.inventory.instances.<instanceName>.actions.build-docker-container
        exports.networking = {
          # TODO add user space network support to clan-cli
          technology = "direct";
          peers = lib.mapAttrs (_name: _machine: {
            host.plain = settings.host;
            SSHOptions = map (_x: "-J x") settings.jumphosts;
          }) roles.default.machines;
        };
      };
  };
}
