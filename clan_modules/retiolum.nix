{
  config,
  clanLib,
  lib,
  ...
}:
{
  _class = "clan.service";
  manifest.name = "retiolum";
  manifest.description = "reach machines as <name>.r over retiolum (tinc); preferred over every other network";
  manifest.categories = [ "Network" ];
  manifest.exports.out = [
    "networking"
    "peer"
  ];

  exports = lib.mapAttrs' (instanceName: _: {
    name = clanLib.buildScopeKey {
      inherit instanceName;
      serviceName = config.manifest.name;
    };
    value = {
      # internet/yggdrasil are 2000; retiolum wins
      networking.priority = 3000;
    };
  }) config.instances;

  roles.default = {
    description = "machine reachable as <name>.r; retiolum itself is configured in 2configs/retiolum.nix";
    perInstance =
      { mkExports, machine, ... }:
      {
        exports = mkExports {
          peer.hosts = [ { plain = "${machine.name}.r"; } ];
        };
      };
  };
}
