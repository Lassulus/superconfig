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

  clan.core.vars.generators.nix-serve = {
    files."nix-serve.key" = { };
    files."nix-serve.pub".secret = false;
    runtimeInputs = with pkgs; [
      coreutils
      nix
    ];
    script = ''
      exit 1  # Manual migration required from facts to vars
      nix-store --generate-binary-cache-key cache.${config.networking.hostName} "$out"/nix-serve.key "$out"/nix-serve.pub
    '';
  };
}
