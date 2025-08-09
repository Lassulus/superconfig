{ config, pkgs, ... }:
{
  # nixpkgs.config.packageOverrides = p: {
  #   nix-serve = p.haskellPackages.nix-serve-ng;
  # };
  # generate private key with:
  # nix-store --generate-binary-cache-key my-secret-key my-public-key
  clan.core.vars.generators.nix-serve = {
    files."nix-serve.key" = { };
    files."nix-serve.pub" = { };
    migrateFact = "nix-serve";
    runtimeInputs = with pkgs; [
      coreutils
      nix
    ];
    script = ''
      nix-store --generate-binary-cache-key "$out"/nix-serve.key "$out"/nix-serve.pub
    '';
  };
  services.nix-serve = {
    enable = true;
    secretKeyFile = config.clan.core.vars.generators.nix-serve.files."nix-serve.key".path;
    port = 5005;
  };

  services.nginx = {
    enable = true;
    virtualHosts.nix-serve = {
      serverAliases = [ "cache.${config.networking.hostName}.r" ];
      locations."/".extraConfig = ''
        proxy_pass http://localhost:${toString config.services.nix-serve.port};
      '';
      locations."= /nix-cache-info".extraConfig = ''
        alias ${pkgs.writeText "cache-info" ''
          StoreDir: /nix/store
          WantMassQuery: 1
          Priority: 42
        ''};
      '';
    };
  };
}
