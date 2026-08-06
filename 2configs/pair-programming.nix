{
  self,
  pkgs,
  ...
}:
{
  users.users.pairprogramming = {
    uid = self.inputs.stockholm.lib.genid_uint31 "pairprogramming";
    createHome = true;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      self.keys.ssh.barnacle.public
      self.keys.ssh.yubi_pgp.public
      self.keys.ssh.yubi1.public
      self.keys.ssh.yubi2.public
      self.keys.ssh.solo2.public
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCTwBH0KIRE+9SC4n7hRAGAA7Lf/+PuCHFZzZDajy9lmYrcQdvD5SgP6Q5OikUxycniI0Zse5Xeitq9qkJNg6Lw= PIV AUTH pubkey" # pinpox
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJZGxQmZeh7mm40vj6BQovhb0//meQXUrBEFI4afNXrLfYFtYEVMmXPEEEfTNi9vuoz2D06JCJptGcOtLaAproM= termux@massulus"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHEEkRtBCPyVHtLeXBEVbEkvL6SzgAbxdoa6xF6r/2N9 kenji"

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
