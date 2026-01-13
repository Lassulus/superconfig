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
in
{
  privateNetwork = true;
  hostBridge = "ctr0";

  # Static IPv6 from hostname hash: fd00:ctr::7371:bba8:ddd5:45e4
  localAddress6 = "fd00:ctr::${ipv6Suffix}/64";

  specialArgs = { inherit self; };

  config = {
    imports = [
      self.inputs.clan-core.nixosModules.clanCore
      ./config.nix
    ];
    clan.core.settings.directory = self;
    clan.core.settings.machine.name = machineName;

    # DNS64 resolvers (Cloudflare)
    networking.nameservers = [
      "2606:4700:4700::64"
      "2606:4700:4700::6400"
    ];
  };
}
