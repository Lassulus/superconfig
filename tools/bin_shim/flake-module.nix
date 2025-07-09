{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    rec {
      packages.bin_shim = pkgs.writeShellApplication {
        name = "bin_shim";
        runtimeInputs = [
          pkgs.jq
        ];
        text = builtins.readFile ./bin_shim.sh;
      };
      legacyPackages.bin_shim =
        {
          pkg_name,
          name ? pkg_name,
        }:
        pkgs.writeScriptBin name ''
          #!/bin/sh
          set -efu
          set -x

          FLAKE=${self} ${lib.getExe packages.bin_shim} ${pkg_name} "$@"
        '';
    };
}
