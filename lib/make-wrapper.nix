{ lib, pkgs, ... }:
{
  /**
    Create a wrapped application that preserves all original outputs (man pages, completions, etc.)

    # Arguments

    - `package`: The package to wrap
    - `runtimeInputs`: List of packages to add to PATH (optional)
    - `env`: Attribute set of environment variables to export (optional)
    - `flags`: Attribute set of command-line flags to add (optional)
    - `flagSeparator`: Separator between flag names and values (optional, defaults to " ")
    - `preHook`: Shell script to run before executing the command (optional)
    - `passthru`: Attribute set to pass through to the wrapped derivation (optional)
    - `wrapper`: Custom wrapper function (optional, defaults to exec'ing the original binary with flags)
      - Called with { env, flags, envString, flagsString, exePath, preHook }

    # Example

    ```nix
    makeWrapper pkgs.curl {
      runtimeInputs = [ pkgs.jq ];
      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      flags = {
        "--silent" = { }; # becomes --silent
        "--connect-timeout" = "30"; # becomes --connect-timeout 30
      };
      preHook = ''
        echo "Making request..." >&2
      '';
    }

    # Or with custom wrapper:
    makeWrapper pkgs.someProgram {
      wrapper = { exePath, flagsString, envString, preHook, ... }: ''
        ${envString}
        ${preHook}
        echo "Custom logic here"
        exec ${exePath} ${flagsString} "$@"
      '';
    }
    ```
  */
  makeWrapper =
    package:
    {
      runtimeInputs ? [ ],
      env ? { },
      flags ? { },
      flagSeparator ? " ", # " " for "--flag value" or "=" for "--flag=value"
      preHook ? "",
      passthru ? { },
      wrapper ? (
        {
          exePath,
          flagsString,
          envString,
          preHook,
          ...
        }:
        ''
          ${envString}
          ${preHook}
          exec ${exePath}${flagsString} "$@"
        ''
      ),
    }:
    let
      # Extract binary name from the exe path
      exePath = lib.getExe package;
      binName = baseNameOf exePath;

      # Generate environment variable exports
      envString =
        if env == { } then
          ""
        else
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: ''export ${name}="${toString value}"'') env
          )
          + "\n";

      # Generate flag arguments with proper line breaks and indentation
      flagsString =
        if flags == { } then
          ""
        else
          " \\\n  "
          + lib.concatStringsSep " \\\n  " (
            lib.mapAttrsToList (
              name: value:
              if value == { } then "${name}" else "${name}${flagSeparator}${lib.escapeShellArg (toString value)}"
            ) flags
          );

      finalWrapper = wrapper {
        inherit
          env
          flags
          envString
          flagsString
          exePath
          preHook
          ;
      };

      # Multi-output aware symlink join function
      multiOutputSymlinkJoin =
        {
          name,
          paths,
          outputs ? [ "out" ],
          originalOutputs ? { },
          passthru ? { },
          meta ? { },
          ...
        }@args:
        pkgs.stdenv.mkDerivation (
          {
            inherit name outputs;

            buildCommand = ''
              # Symlink all paths to the main output
              mkdir -p $out
              for path in ${lib.concatStringsSep " " (map toString paths)}; do
                ${pkgs.lndir}/bin/lndir -silent "$path" $out
              done

              # Handle additional outputs by symlinking from the original package's outputs
              ${lib.concatMapStringsSep "\n" (
                output:
                if output != "out" && originalOutputs ? ${output} && originalOutputs.${output} != null then
                  ''
                    if [[ -n "''${${output}:-}" ]]; then
                      mkdir -p ${"$" + output}
                      # Only symlink from the original package's corresponding output
                      ${pkgs.lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${"$" + output}
                    fi
                  ''
                else
                  ""
              ) outputs}
            '';

            inherit passthru meta;
          }
          // (removeAttrs args [
            "name"
            "paths"
            "outputs"
            "originalOutputs"
            "passthru"
            "meta"
          ])
        );

      # Get original package outputs for symlinking
      originalOutputs =
        if package ? outputs then
          lib.listToAttrs (
            map (output: {
              name = output;
              value = if package ? ${output} then package.${output} else null;
            }) package.outputs
          )
        else
          { };

      # Create the wrapper derivation using our multi-output aware symlink join
      wrappedPackage = multiOutputSymlinkJoin (
        {
          name = package.pname or package.name;
          paths = [
            (pkgs.writeShellApplication {
              name = binName;
              runtimeInputs = runtimeInputs;
              text = finalWrapper;
            })
            package
          ];
          outputs = if package ? outputs then package.outputs else [ "out" ];
          inherit originalOutputs;
          passthru =
            (package.passthru or { })
            // passthru
            // {
              inherit env flags preHook;
            };
          # Pass through original attributes
          meta = package.meta or { };
        }
        // lib.optionalAttrs (package ? version) {
          inherit (package) version;
        }
        // lib.optionalAttrs (package ? pname) {
          inherit (package) pname;
        }
      );
    in
    wrappedPackage;
}
