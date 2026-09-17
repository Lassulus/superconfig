{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.flix-prune =
        (pkgs.writeShellApplication {
          name = "flix-prune";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.curl
            pkgs.gawk
            pkgs.gnused
            pkgs.jq
            pkgs.sqlite
          ];
          text = builtins.readFile ./flix-prune.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
