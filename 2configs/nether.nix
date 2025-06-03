{ self, ... }:
{
  imports = [
    self.inputs.nether.nixosModules.hosts
  ];
  clan.core.networking.zerotier = {
    networkId = "ccc5da5295c853d4";
    name = "nether";
  };
  services.zerotierone.localConf = {
    settings.interfacePrefixBlacklist = [
      "retiolum"
      "wiregrill"
      "mycelium"
    ];
  };
}
