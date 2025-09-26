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
  /**
    A function to create a wrapper module.
    returns an attribute set with options and apply function.

    Example usage:
      helloWrapper = mkWrapper (wlib: { config, ... }: {
        options.greeting = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
        config.package = config.pkgs.hello;
        config.flags = {
          "--greeting" = config.greeting;
        };
      };

      helloWrapper.apply {
        pkgs = pkgs;
        greeting = "hi";
      };

      # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
  */
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
        # we need to pass pkgs here, because writeText is in pkgs
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
                description = ''
                  The nixpkgs pkgs instance to use.
                  We want to have this, so wrapper modules can be system agnostic.
                '';
              };
              package = lib.mkOption {
                type = lib.types.package;
                description = ''
                  The base package to wrap.
                  This means we inherit all other files from this package
                  (like man page, /share, ...)
                '';
              };
              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = ''
                  Additional packages to add to the wrapper's runtime dependencies.
                  This is useful if the wrapped program needs additional libraries or tools to function correctly.
                  These packages will be added to the wrapper's runtime dependencies, ensuring they are available when the wrapped program is executed.
                '';
              };
              flags = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
                default = { };
                description = ''
                  Flags to pass to the wrapper.
                  The key is the flag name, the value is the flag value.
                  If the value is true, the flag will be passed without a value.
                  If the value is false or null, the flag will not be passed.
                  If the value is a list, the flag will be passed multiple times with each value.
                '';
              };
              env = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = ''
                  Environment variables to set in the wrapper.
                '';
              };
              passthru = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = ''
                  Additional attributes to add to the resulting derivation's passthru.
                  This can be used to add additional metadata or functionality to the wrapped package.
                  This will always contain options, config and settings, so these are reserved names and cannot be used here.
                '';
              };
            };
          }
        ];
      };
    in
    {
      # expose options to generate documentation of available modules
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
