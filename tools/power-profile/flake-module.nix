{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.power-profile = (pkgs.writeShellApplication {
        name = "power-profile";
        text = builtins.readFile ./power-profile.sh;
      }).overrideAttrs { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
