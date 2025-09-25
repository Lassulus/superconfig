{ self, lib, ... }:
{
  imports = [
    ./mpv/default.nix
    ./notmuch/default.nix
  ];
  flake.options.wrapperModules = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.unspecified);
    default = { };
    description = "Wrapper modules";
  };
  flake.config.wrapLib.mkWrapper =
    declarationArgs:
    let
      declaration = declarationArgs wrapperLib;

      wrapperLib = {
        types = {
          inherit file;
        };
      };
      file =
        pkgs:
        lib.types.submodule (
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
                defaultText = "pkgs.writeText name <content>";
              };
            };
          }
        );
      evalArgs = cfg: {
        modules = [
          declaration
          cfg
          {
            options = {
              pkgs = lib.mkOption {
                description = "The pkgs to use.";
              };
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
              env = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
              };
              passthru = lib.mkOption {
                type = lib.types.attrs;
                default = { };
              };
            };
          }
        ];
      };
    in
    {
      options = (lib.evalModules (evalArgs { })).options;
      apply =
        settings:
        let
          eval = lib.evalModules (evalArgs {
            config = settings;
          });
          options = eval.options;
          config = eval.config;
        in
        self.libWithPkgs.${config.pkgs.system}.makeWrapper config.package {
          runtimeInputs = config.extraPackages;
          flagSeparator = "=";
          flags = config.flags;
          env = config.env;
          passthru = {
            inherit options config settings;
          }
          // config.passthru;
        };
    };
}
