{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.say =
        (pkgs.writeShellApplication {
          name = "say";
          runtimeInputs = [
            pkgs.flite
            pkgs.libnotify
          ];
          text = builtins.readFile ./say.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
