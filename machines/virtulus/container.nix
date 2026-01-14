{ self }:
let
  lib = self.inputs.nixpkgs.lib;
  hashlib = self.inputs.nix-hashlib.lib;

  # Generate IPv6 suffix from hostname (16 hex chars = 64 bits)
  ipv6SuffixFun = hashlib.makeHashFun {
    type = "hash";
    dictionary = lib.stringToCharacters "0123456789abcdef";
    length = 16;
  };

  formatIPv6Suffix = hash:
    "${builtins.substring 0 4 hash}:${builtins.substring 4 4 hash}:${builtins.substring 8 4 hash}:${builtins.substring 12 4 hash}";

  machineName = "virtulus";
  ipv6Suffix = formatIPv6Suffix (ipv6SuffixFun machineName);
  ipv6Address = "fd00:c700::${ipv6Suffix}";
in
{
  privateNetwork = true;
  hostBridge = "ctr0";

  specialArgs = { inherit self; };

  config = {
    imports = [
      self.inputs.clan-core.nixosModules.clanCore
      ./config.nix
    ];
    clan.core.settings.directory = self;
    clan.core.settings.machine.name = machineName;

    # Configure IPv6 inside the container (on eth0 interface)
    systemd.network.networks."10-container" = {
      matchConfig.Name = "eth0";
      address = [ "${ipv6Address}/64" ];
      gateway = [ "fd00:c700::1" ];
      networkConfig.ConfigureWithoutCarrier = true;
    };

    # Use host's local DNS64 resolver
    networking.nameservers = [ "fd00:c700::1" ];
  };
}
