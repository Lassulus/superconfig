{
  description = "lassulus superconfig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "path:/home/lass/tmp/nixpkgs-disk-debug";
    # nixpkgs.url = "git+file:/home/lass/src/nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    astro-nvim.url = "github:AstroNvim/AstroNvim";
    astro-nvim.flake = false;

    clan-core.url = "git+https://git.clan.lol/clan/clan-core";
    # clan-core.url = "git+file:/home/lass/src/clan/clan-core";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.flake-parts.follows = "flake-parts";
    clan-core.inputs.disko.follows = "disko";

    stockholm.url = "github:krebs/stockholm";
    # stockholm.url = "git+https://cgit.lassul.us/stockholm";
    # stockholm.url = "path:/home/lass/sync/stockholm";
    stockholm.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    # disko.url = "path:/home/lass/src/disko/";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    data-mesher.url = "https://git.clan.lol/clan/data-mesher/archive/main.tar.gz";
    # data-mesher.url = "path:/home/lass/src/data-mesher/";
    data-mesher.inputs.nixpkgs.follows = "nixpkgs";

    nether.url = "github:krebs/nether";
    # nether.url = "git+file:/home/lass/src/nether";
    nether.inputs.nixpkgs.follows = "nixpkgs";
    nether.inputs.clan-core.follows = "clan-core";
    nether.inputs.data-mesher.follows = "data-mesher";

    spora.url = "github:krebs/spora";
    # spora.url = "git+file:/home/lass/src/spora";
    spora.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter.url = "github:numtide/nixos-facter-modules";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      clan-core,
      ...
    }:
    let
      clan = clan-core.lib.buildClan {
        directory = self;
        specialArgs.self = self;
        machines = nixpkgs.lib.mapAttrs (machineName: _: {

          imports = [
            ./machines/${machineName}/physical.nix
            (
              { config, ... }:
              {
                clan.core.machineName = machineName;
                clan.core.facts.secretStore = "password-store";
                clan.core.facts.secretUploadDirectory = nixpkgs.lib.mkDefault "/etc/secrets";
                clan.networking.targetHost = "root@${machineName}";
                krebs.secret.directory = config.clanCore.facts.secretUploadDirectory;
                nixpkgs.overlays = [
                  self.inputs.stockholm.overlays.default
                  (import (self.inputs.stockholm.inputs.nix-writers + "/pkgs")) # TODO get rid of that overlay
                ];
              }
            )
            ./2configs
            ./3modules
            self.inputs.stockholm.nixosModules.krebs
          ];
        }) (builtins.readDir ./machines);
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        ./tools/nvim.nix
        ./tools/astronvim/flake-module.nix
        ./tools/zsh.nix
        ./tools/get-spora-hosts.nix
        ./formatter.nix
      ];
      flake.nixosConfigurations = clan.nixosConfigurations;
      flake.clanInternals = clan.clanInternals;
      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        {
          packages = lib.mapAttrs (name: _v_: pkgs.callPackage ./5pkgs/${name} { }) (
            builtins.readDir ./5pkgs
          );
          devShells.default = pkgs.mkShell {
            packages = [
              clan-core.packages.${system}.clan-cli
            ];
          };
        };
      flake.darwinConfigurations.barnacle = inputs.nix-darwin.lib.darwinSystem {
        modules = [ ./darwin/barnacle/config.nix ];
      };
    };
}
