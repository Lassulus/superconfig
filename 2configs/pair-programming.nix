{ self, config, ... }:
{
  users.users.pairprogramming = {
    uid = self.inputs.stockholm.lib.genuid_uint31 "pairprogramming";
    createHome = true;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      config.krebs.users.lass.pubkey
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJ4yq7oHBO2iPs4xj797a//0ypnBr27sSadKUeL2NsK6AAAABHNzaDo=" # janik
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOYg513QZsVzoyVycXZjg4F3T3+OwtcY3WAhrlfyLgLTAAAABHNzaDo=" # janik
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBLZxVITpJ8xbiCa/u2gjSSIupeiqOnRh+8tFIoVhCON" # janik
    ];
  };
}
