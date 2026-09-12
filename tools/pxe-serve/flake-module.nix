{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      packages.pxe-serve =
        (pkgs.writeShellApplication {
          name = "pxe-serve";
          runtimeInputs = [
            pkgs.nix
            pkgs.iproute2
            pkgs.gawk
            pkgs.coreutils
            config.packages.pxe-share
          ];
          text = builtins.readFile ./pxe-serve.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
