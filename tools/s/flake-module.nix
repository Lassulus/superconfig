{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.s = pkgs.writers.writeDashBin "s" ''
        set -efu

        # Use local checkout if it exists, otherwise fall back to self
        if [ -d "$HOME/src/superconfig" ]; then
          flake="$HOME/src/superconfig"
        else
          flake="${self}"
        fi

        if [ $# -eq 0 ]; then
          echo "Usage: s <package> [args...]" >&2
          echo "Runs a package from superconfig ($flake)" >&2
          exit 1
        fi

        pkg="$1"
        shift

        exec ${pkgs.nix}/bin/nix run "$flake#$pkg" -- "$@"
      '';
    };
}
