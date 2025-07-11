{
  description = "lassulus superconfig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "path:/home/lass/tmp/nixpkgs-disk-debug";
    # nixpkgs.url = "git+file:/home/lass/src/nixpkgs";
    # nixpkgs.url = "git+file:/Users/lassulus/src/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    clan-core.url = "git+https://git.clan.lol/clan/clan-core";
    # clan-core.url = "path:/Users/lassulus/src/clan/clan-core";
    # clan-core.url = "git+file:/home/lass/src/clan/clan-core";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.flake-parts.follows = "flake-parts";
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
      flake-parts,
      nixpkgs,
      clan-core,
      ...
    }:
    let
      clan = clan-core.lib.buildClan {
        self = self;
        specialArgs.self = self;
        exportsModule =
          { lib, ... }:
          {
            options.networking = {
              priority = lib.mkOption {
                type = lib.types.int;
                default = 1000;
                description = ''
                  priority with which this network should be tried.
                  higher priority means it gets used earlier in the chain
                '';
              };
              technology = lib.mkOption {
                # addding more technologies requires code in the clan-cli to handle that technology
                # at least for userspace networking
                # maybe we can do a fallback mode for vpns where we don't need userspace networking?
                type = lib.types.enum [
                  "direct"
                  "tor"
                ];
                description = ''
                  the technology this network uses to connect to the target
                  This is used for userspace networking with socks proxies.
                '';
              };
              # should we call this machines? hosts?
              peers = lib.mkOption {
                # <name>
                type = lib.types.attrsOf (
                  lib.types.submodule (
                    { name, ... }:
                    {
                      options = {
                        name = lib.mkOption {
                          type = lib.types.str;
                          default = name;
                        };
                        SSHOptions = lib.mkOption {
                          type = lib.types.listOf lib.types.str;
                          default = [ ];
                        };
                        host = lib.mkOption {
                          description = '''';
                          type = lib.types.attrTag {
                            plain = lib.mkOption {
                              type = lib.types.str;
                              description = ''
                                a plain value, which can be read directly from the config
                              '';
                            };
                            var = lib.mkOption {
                              type = lib.types.submodule {
                                options = {
                                  machine = lib.mkOption {
                                    type = lib.types.str;
                                    example = "jon";
                                  };
                                  generator = lib.mkOption {
                                    type = lib.types.str;
                                    example = "tor-ssh";
                                  };
                                  file = lib.mkOption {
                                    type = lib.types.str;
                                    example = "hostname";
                                  };
                                };
                              };
                            };
                          };
                        };
                      };
                    }
                  )
                );
              };
            };
          };
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
              module.name = "tor";
              module.input = "self";
              roles.default.tags.all = { };
            };
            internet = {
              module.name = "internet";
              module.input = "self";
              roles.default.machines = {
                prism.settings.host = "prism.lassul.us";
                neoprism.settings.host = "neoprism.lassul.us";
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
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports =
        [
          ./formatter.nix
          ./5pkgs/flake-module.nix
          ./keys/flake-module.nix
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
              (self.legacyPackages.${system}.bin_shim {
                name = "clan";
                pkg_name = "clan-cli";
              })
            ];
          };
        };
      flake.lib = import ./lib { inherit (nixpkgs) lib; };
      flake.libWithPkgs = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        import ./lib/pkgs.nix {
          inherit (nixpkgs) lib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
    };
}
