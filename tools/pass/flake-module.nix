{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      passWithOtp = pkgs.pass.withExtensions (ext: [ ext.pass-otp ]);
    in
    {
      packages.pass = self.libWithPkgs.${system}.makeWrapper passWithOtp {
        runtimeInputs = [ pkgs.gnupg ];
        wrapper =
          { exePath, envString, ... }:
          ''
            ${envString}
            gpg --import ${self.keys.pgp.yubi.key} &>/dev/null
            echo '${self.keys.pgp.yubi.id}:6:' | gpg --import-ownertrust &>/dev/null
            exec ${exePath} "$@"
          '';
      };
    };
}
