
{ self, ... }:
{
  perSystem =
    { pkgs, ... }: {
      packages.pass = pkgs.symlinkJoin {
        name = "pass";
        paths = [
          (pkgs.writeShellApplication {
            name = "pass";
            runtimeInputs = [
              pkgs.pass
              pkgs.gnupg
            ];
            text = ''
              set -x
              gpg --import ${self.keys.pgp.yubi.key}
              echo '${self.keys.pgp.yubi.id}:6:' | gpg --import-ownertrust
              pass "$@"
            '';
          })
          pkgs.pass
        ];
      };
    };
}
