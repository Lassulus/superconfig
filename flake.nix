{
  description = "lassulus superconfig";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:lassulus/nixpkgs/nixos-unstable";
    # nixpkgs.url = "path:/home/lass/tmp/nixpkgs-disk-debug";
    # nixpkgs.url = "git+file:/home/lass/src/nixpkgs";
    # nixpkgs.url = "git+file:/Users/lassulus/src/nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    clan-core.url = "git+https://git.clan.lol/clan/clan-core";
    # clan-core.url = "path:/Users/lassulus/src/clan/clan-core";
    # clan-core.url = "git+file:/home/lass/src/clan/clan-core";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.disko.follows = "disko";

    stockholm.url = "git+https://github.com/krebs/stockholm?submodules=1";
    # stockholm.url = "git+https://cgit.lassul.us/stockholm";
    # stockholm.url = "path:/home/lass/sync/stockholm";
    stockholm.inputs.nixpkgs.follows = "nixpkgs";
    stockholm.inputs.buildbot-nix.follows = "";

    disko.url = "github:nix-community/disko";
    # disko.url = "path:/home/lass/src/disko/";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nether.url = "github:krebs/nether";
    # nether.url = "git+file:/home/lass/src/nether";
    nether.inputs.nixpkgs.follows = "nixpkgs";
    nether.inputs.clan-core.follows = "clan-core";
    nether.inputs.data-mesher.follows = "";

    spora.url = "github:krebs/spora";
    # spora.url = "git+file:/home/lass/src/spora";
    spora.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";
    nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter.url = "github:numtide/nixos-facter-modules";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    le_menu.url = "github:lassulus/le_menu";
    # le_menu.url = "git+file:/home/lass/src/le_menu";
    le_menu.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      clan-core,
      ...
    }:
    let
      clan = clan-core.lib.buildClan {
        self = self;
        specialArgs.self = self;
        modules = import ./clan_modules { inherit nixpkgs; };
        inventory = {
          meta.name = "superconfig";
          machines = {
            ignavia.tags = [
              "laptop"
              "focus"
            ];
            mors.tags = [
              "laptop"
              "focus"
            ];
            aergia.tags = [
              "laptop"
              "focus"
            ];
            barnacle = {
              machineClass = "darwin";
              tags = [
                "laptop"
                "focus"
              ];
            };
            icarus.tags = [ "laptop" ];
            prism.tags = [ "server" ];
            neoprism.tags = [ "server" ];
          };
          instances = {
            tor = {
              roles.server.tags.all = { };
            };
            internet = {
              roles.default.machines = {
                prism.settings.host = "ssh://prism.lassul.us:45621";
                neoprism.settings.host = "ssh://neoprism.lassul.us:45621";
              };
            };
            state-version = {
              module.name = "importer";
              roles.default.tags.all = { };
              roles.default.settings.extraModules = [
                {
                  clan.core.state-version.enable = true;
                }
              ];
            };
          };
        };
        machines =
          nixpkgs.lib.mapAttrs
            (machineName: _: {
              imports = [
                ./machines/${machineName}/physical.nix
              ];
            })
            (
              nixpkgs.lib.filterAttrs (
                machineName: _: builtins.pathExists ./machines/${machineName}/physical.nix
              ) (builtins.readDir ./machines)
            );
      };
    in
    clan-core.inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [
        ./formatter.nix
        ./5pkgs/flake-module.nix
        ./keys/flake-module.nix
        ./wrapperModules/flake-module.nix
      ]
      ++ (
        # Auto-import all flake-module.nix files from tools subdirectories
        let
          toolDirs = builtins.attrNames (
            nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./tools)
          );
        in
        map (dir: ./tools + "/${dir}/flake-module.nix") toolDirs
      );
      flake.nixosConfigurations = clan.nixosConfigurations;
      flake.clanInternals = clan.clanInternals;
      flake.darwinConfigurations = clan.darwinConfigurations;
      flake.clan = clan;
      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        {
          packages = {
            default = inputs.le_menu.lib.buildMenu {
              inherit pkgs;
              menuConfig = {
                vim.run = "nix run ${self}#nvim";
                shell.run = "nix run ${self}#shell";
                machines.submenu = lib.mapAttrs (name: _machine: {
                  submenu.ssh.submenu = {
                    retiolum.run = "ssh -t ${name}.r";
                    spora.run = "ssh ${name}.s";
                    nether.run = "ssh ${name}.n";
                    tor.run = "torify ssh $(pass show machines/${name}/tor-hostname)";
                  };
                }) self.nixosConfigurations;
                debug.run = "env";
              };
            };
            clan-cli = clan-core.packages.${system}.clan-cli;
          };
          devShells.default = pkgs.mkShell {
            packages = [
              nixpkgs.legacyPackages.${system}.nil
              nixpkgs.legacyPackages.${system}.nixd
              self.packages.${pkgs.system}.pass
              (self.legacyPackages.${system}.bin_shim {
                name = "clan";
                pkg_name = "clan-cli";
              })
            ];
          };
        };
      flake.lib = import ./lib { inherit (nixpkgs) lib; };
    };
}
