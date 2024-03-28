{ config, pkgs, ... }:
{
  nixpkgs.config.packageOverrides = p: {
    nix-serve = p.haskellPackages.nix-serve-ng;
  };

  services.nix-serve = {
    enable = true;
    port = 5005;
    secretKeyFile = "${config.krebs.secret.directory}/nix-serve.key";
  };

  clanCore.facts.services.nix-serve = {
    secret."nix-serve.key" = { };
    public."nix-serve.pub" = { };
    generator.path = with pkgs; [ coreutils nix ];
    generator.script = ''
      nix-store --generate-binary-cache-key cache.${config.networking.hostName} "$secrets"/nix-serve.key "$facts"/nix-serve.pub
    '';
  };
}
