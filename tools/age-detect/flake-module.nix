{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.age-detect = pkgs.writeShellApplication {
        name = "age-detect";
        runtimeInputs =
          with pkgs;
          [
            age
            age-plugin-yubikey
            age-plugin-fido2-hmac
            yubikey-manager
            libfido2
          ]
          ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.age-plugin-se
          ]);
        text = builtins.readFile ./age-detect;
      };
    };
}
