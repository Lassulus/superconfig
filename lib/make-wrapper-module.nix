{
  lib,
  superlib,
  pkgs,
}:
let
  makeWrapper = (import ./make-wrapper.nix { inherit lib superlib pkgs; }).makeWrapper;
in
{
  /**
    Create a wrapper module that combines NixOS module evaluation with makeWrapper functionality.

    This function creates a reusable wrapper configuration that can be instantiated
    with different settings using the NixOS module system.

    # Arguments

    - `name`: String identifier for the wrapper module
    - `options`: Attribute set of `lib.mkOption` definitions for configurable settings
    - `module`: Function that receives the evaluated config and returns:
      - `package`: The base package to wrap (required)
      - All other makeWrapper parameters (wrapper, env, runtimeInputs, etc.)

    # Returns

    A function that takes settings and returns the wrapped package.

    # Example

    ```nix
    # Define the wrapper module
    muttWrapperModule = makeWrapperModule {
      name = "mutt";
      options = {
        muttrc = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Mutt configuration";
        };
        editor = lib.mkOption {
          type = lib.types.str;
          default = "vim";
          description = "Editor to use for composing emails";
        };
      };
      module = { config, pkgs, ... }: {
        package = pkgs.mutt;
        env = {
          EDITOR = config.editor;
        };
        wrapper = { exePath, ... }: ''
          exec ${exePath} -F ${pkgs.writeText "muttrc" config.muttrc} "$@"
        '';
      };
    };

    # Use with settings
    packages.mutt = muttWrapperModule {
      muttrc = ''
        set editor = "nvim"
        set sort = threads
      '';
      editor = "nvim";
    };
    ```
  */
  makeWrapperModule =
    {
      name,
      options,
      module,
    }:
    # Return a function that takes settings
    settings:
    let
      # Evaluate the module with the provided settings
      evaluated = lib.evalModules {
        modules = [
          # Base module with options
          {
            options = options;
          }
          # The wrapper module definition
          module
          # User settings
          {
            config = settings;
          }
        ];
        # Provide standard module arguments
        specialArgs = {
          inherit pkgs lib;
        };
      };

      # Extract the evaluated config
      config = evaluated.config;

      # The module must provide a package
      package =
        config.package or (throw "makeWrapperModule '${name}': module must define a 'package' attribute");

      # Extract makeWrapper parameters from config (excluding 'package')
      wrapperArgs = lib.filterAttrs (n: _v: n != "package") config;
    in
    # Call makeWrapper with the package and extracted arguments
    makeWrapper package wrapperArgs;
}
