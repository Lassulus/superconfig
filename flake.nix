{
  description = "lassulus superconfig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "path:/home/lass/tmp/nixpkgs-disk-debug";
    # nixpkgs.url = "git+file:/home/lass/src/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    clan-core.url = "git+https://git.clan.lol/clan/clan-core";
    # clan-core.url = "path:///home/lass/src/clan/clan-core";
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
          services = {
            state-version.x.roles.default.tags = [
              "all"
            ];
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
      perSystem =
        {
          lib,
          pkgs,
          system,
          ...
        }:
        {
          packages =
            (lib.mapAttrs (name: _v_: pkgs.callPackage ./5pkgs/${name} { }) (builtins.readDir ./5pkgs))
            // {
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

              # Script to build installer ISO with custom vars
              build-installer-iso = pkgs.writeShellScriptBin "build-installer-iso" ''
                set -euo pipefail
                set -x

                # Default values
                OUTPUT="installer.iso"
                ARCH="x86_64-linux"  # Default to x86_64-linux for cross-compilation
                VARS_DIR=""

                usage() {
                  cat <<EOF
                Usage: $0 [OPTIONS]

                Build a NixOS installer ISO with custom vars appended.

                OPTIONS:
                  -o, --output FILE     Output ISO file (default: installer.iso)
                  -a, --arch ARCH       Architecture: x86_64-linux or aarch64-linux (default: x86_64-linux)
                  -v, --vars DIR        Directory containing vars to append to ISO
                  -h, --help            Show this help message

                EXAMPLE:
                  $0 -o my-installer.iso -v ./my-vars -a x86_64-linux
                EOF
                }

                # Parse arguments
                while [[ $# -gt 0 ]]; do
                  case $1 in
                    -o|--output)
                      OUTPUT="$2"
                      shift 2
                      ;;
                    -a|--arch)
                      ARCH="$2"
                      shift 2
                      ;;
                    -v|--vars)
                      VARS_DIR="$2"
                      shift 2
                      ;;
                    -h|--help)
                      usage
                      exit 0
                      ;;
                    *)
                      echo "Unknown option: $1"
                      usage
                      exit 1
                      ;;
                  esac
                done

                # Build the base ISO
                echo "Building base ISO for $ARCH..."
                BASE_ISO=$(nix build -L --no-link --print-out-paths ${self}#clanInternals.machines.$ARCH.installer.config.system.build.images.iso-installer)

                if [ -z "$VARS_DIR" ]; then
                  # No vars specified, just copy the base ISO
                  echo "No vars directory specified, copying base ISO..."
                  cp "$BASE_ISO"/iso/*.iso "$OUTPUT"
                else
                  # Append vars using xorriso - preserve boot structure
                  echo "Appending vars from $VARS_DIR to ISO..."
                  ${pkgs.xorriso}/bin/xorriso \
                    -indev "$BASE_ISO"/iso/*.iso \
                    -outdev "$OUTPUT" \
                    -boot_image any replay \
                    -map "$VARS_DIR" /vars \
                    -commit_eject all
                fi

                echo "ISO created: $OUTPUT"
              '';
            };
          devShells.default = pkgs.mkShell {
            packages = [
              clan-core.packages.${system}.clan-cli
              nixpkgs.legacyPackages.${system}.nil
              nixpkgs.legacyPackages.${system}.nixd
            ];
          };
        };
      flake.keys = {
        pgp.yubi = {
          key = ./keys/yubi.pgp;
          id = "DBCD757846069B392EA9401D6657BE8A8D1EE807";
        };
        ssh = builtins.readFile ./keys/yubi.ssh;
      };
    };
}
