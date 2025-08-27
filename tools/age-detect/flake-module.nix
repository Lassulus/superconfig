{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.age-detect = pkgs.writeShellApplication {
        name = "age-detect";
        runtimeInputs = with pkgs; [
          age
          age-plugin-yubikey
          age-plugin-fido2-hmac
          age-plugin-se
          yubikey-manager
          libfido2
        ];
        text = builtins.readFile ./age-detect;
      };
    };
}