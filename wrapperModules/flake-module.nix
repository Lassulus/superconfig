{ self, lib, ... }:
{
  imports = [
    ./mpv/default.nix
  ];
  flake.wrapLib.mkWrapper =
    argsFun: settings:
    let
      args = argsFun wrapperLib;
      pkgs = args.pkgs;
      module = args.module;

      wrapperLib = {
        types = {
          inherit file;
        };
      };
      file = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            content = lib.mkOption {
              type = lib.types.lines;
              description = ''
                content of file
              '';
            };
            path = lib.mkOption {
              type = lib.types.path;
              description = ''
                the path to the file
              '';
              default = pkgs.writeText name config.content;
            };
          };
        }
      );
      eval = lib.evalModules {
        modules = [
          module
          {
            options = {
              package = lib.mkOption {
                type = lib.types.package;
                description = "The base package to use.";
              };
              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              flags = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
                default = { };
              };
              passthru = lib.mkOption {
                type = lib.types.attrs;
                default = { };
              };
            };
            config = settings;
          }
        ];
      };
      config = eval.config;
      options = eval.options;
    in
    self.libWithPkgs.${pkgs.system}.makeWrapper config.package {
      runtimeInputs = config.extraPackages;
      flagSeparator = "=";
      flags = config.flags;
      passthru = {
        inherit options config settings;
      }
      // config.passthru;
    };
}
