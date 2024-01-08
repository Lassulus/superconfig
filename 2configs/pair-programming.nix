{ self, config, pkgs, ... }:
{
  users.users.pairprogramming = {
    uid = self.inputs.stockholm.lib.genid_uint31 "pairprogramming";
    createHome = true;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      config.krebs.users.lass.pubkey
      config.krebs.users.mic92.pubkey
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJ4yq7oHBO2iPs4xj797a//0ypnBr27sSadKUeL2NsK6AAAABHNzaDo=" # janik
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOYg513QZsVzoyVycXZjg4F3T3+OwtcY3WAhrlfyLgLTAAAABHNzaDo=" # janik
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBLZxVITpJ8xbiCa/u2gjSSIupeiqOnRh+8tFIoVhCON" # janik
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJXGRXiq61BQBUkQLBn720pzxiAZqchHWm504gWa2rE2" # kenji
    ];
  };

  virtualisation.podman.enable = true;


  environment.systemPackages = [
    pkgs.ripgrep
    pkgs.lazygit
    pkgs.comma
  ];

  # clan dev related stuff
  nix.settings.trusted-substituters = [
    "https://cache.clan.lol"
  ];
  nix.settings.trusted-public-keys = [
    "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
  ];
}
