{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.pass = pkgs.symlinkJoin {
        name = "pass";
        paths = [
          (pkgs.writeShellApplication {
            name = "pass";
            runtimeInputs = [
              (pkgs.pass.withExtensions (ext: [ ext.pass-otp ]))
              pkgs.gnupg
            ];
            text = ''
              set -efu
              gpg --import ${self.keys.pgp.yubi.key} &>/dev/null
              echo '${self.keys.pgp.yubi.id}:6:' | gpg --import-ownertrust &>/dev/null
              pass "$@"
            '';
          })
          (pkgs.pass.withExtensions (ext: [ ext.pass-otp ]))
        ];
      };
    };
}
