
{ ... }:
{
  perSystem =
    { pkgs, ... }: {
      packages.wifi-qr = pkgs.writeShellApplication {
        name = "wifi-qr";
        runtimeInputs = [
          pkgs.zbar
          pkgs.gawk
        ];
        text = builtins.readFile ./wifi-qr.sh;
      };
    };
}
