{ config, lib, pkgs, ...}:
{
  # nixpkgs.config.packageOverrides = p: {
  #   nix-serve = p.haskellPackages.nix-serve-ng;
  # };
  # generate private key with:
  # nix-store --generate-binary-cache-key my-secret-key my-public-key
  services.nix-serve = {
    enable = true;
    secretKeyFile = "${config.krebs.secret.directory}/nix-serve.key";
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

