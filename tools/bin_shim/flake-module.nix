{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      legacyPackages.bin_shim =
        {
          pkg_name,
          name ? pkg_name,
        }:
        pkgs.writeScriptBin name ''
          #!/bin/sh
          set -efu

          nix --extra-experimental-features 'flakes nix-command' run .#${pkg_name} -- "$@"
        '';
    };
}
