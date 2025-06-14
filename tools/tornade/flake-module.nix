{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.tornade = pkgs.writeShellApplication {
        name = "tornade";
        runtimeInputs = with pkgs; [
          tor
          torsocks
          coreutils
          procps
        ];
        text = builtins.readFile ./tornade.sh;
      };
    };
}