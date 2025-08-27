{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.ssh-yubikey = self.libWithPkgs.${pkgs.system}.makeWrapper pkgs.openssh {
        env = {
          KEYS_DIR = "${self}/keys";
          SSH = "${pkgs.openssh}/bin/ssh";
        };
        runtimeInputs = with pkgs; [
          age
          age-plugin-yubikey
          age-plugin-fido2-hmac
          yubikey-manager
          libfido2
          self.packages.${pkgs.system}.age-detect
        ];
        wrapper = { exePath, envString, ... }: ''
          ${envString}
          ${builtins.readFile ./ssh-yubikey}
        '';
      };
    };
}