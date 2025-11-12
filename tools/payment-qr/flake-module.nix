{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.payment-qr = pkgs.writeShellApplication {
        name = "payment-qr";
        runtimeInputs = [
          pkgs.qrencode
        ];
        text = builtins.readFile ./payment-qr.sh;
      };
    };
}
