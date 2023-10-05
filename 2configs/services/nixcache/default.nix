{ config, lib, pkgs, ... }:
{
  nixpkgs.config.packageOverrides = p: {
    nix-serve = p.haskellPackages.nix-serve-ng;
  };

  services.nix-serve = {
    enable = true;
    port = 5005;
    secretKeyFile = "${config.krebs.secret.directory}/nix-serve.key";
  };
}
