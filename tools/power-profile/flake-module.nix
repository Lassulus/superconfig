{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.power-profile = pkgs.writeShellApplication {
        name = "power-profile";
        runtimeInputs = [
          pkgs.ryzenadj
        ];
        text = builtins.readFile ./power-profile.sh;
      };
    };
}
