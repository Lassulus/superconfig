{ self, lib, ... }:
{
  imports = [
    self.inputs.nether.nixosModules.hosts
  ];
  clan.networking.zerotier = {
    networkId = "ccc5da5295c853d4";
    name = "nether";
  };
}
