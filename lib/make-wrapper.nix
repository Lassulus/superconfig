{ lib, superlib, pkgs, ... }:
{
  /**
    Create a wrapped application that preserves all original outputs (man pages, completions, etc.)

    # Arguments

    - `package`: The package to wrap
    - `runtimeInputs`: List of packages to add to PATH (optional)
    - `env`: Attribute set of environment variables to export (optional)
    - `wrapper`: Custom wrapper script (optional, defaults to exec'ing the original binary)

    # Example

    ```nix
    makeWrapper pkgs.curl {
      runtimeInputs = [ pkgs.jq ];
      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      wrapper = ''
        echo "Making request..." >&2
        exec ${lib.getExe pkgs.curl} "$@"
      '';
    }
    ```
  */
  makeWrapper = package: args@{
    runtimeInputs ? [],
    env ? {},
    wrapper ? ''exec ${lib.getExe package} "$@"''
  }:
    let
      # Extract binary name from the exe path
      exePath = lib.getExe package;
      binName = baseNameOf exePath;
    in
    pkgs.symlinkJoin {
      name = package.pname or package.name;
      paths = [
        (pkgs.writeShellApplication {
          name = binName;
          runtimeInputs = runtimeInputs;
          text = ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: value: ''export ${name}="${toString value}"'') env
            )}
            ${wrapper}
          '';
        })
        package
      ];
    };
}