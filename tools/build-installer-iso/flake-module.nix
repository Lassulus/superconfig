{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.build-installer-iso = pkgs.writeShellApplication {
        name = "build-installer-iso";
        runtimeInputs = with pkgs; [
          xorriso
          coreutils
          nix
        ];
        text = ''
          # Export flake root for the script to use
          export FLAKE_ROOT="${self}"
          ${builtins.readFile ./build-installer-iso.sh}
        '';
      };
    };
}