{ self, ... }:
{
  imports = [
    self.inputs.nether.nixosModules.hosts
    self.inputs.nether.nixosModules.mesher
  ];
  clan.networking.zerotier = {
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
