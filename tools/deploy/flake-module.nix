{ self, inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages.deploy = pkgs.writeShellApplication {
        name = "deploy";
        runtimeInputs = [
          self.packages.${system}.pass
          inputs.clan-core.packages.${system}.clan-cli
        ];
        text = ''
          set -x
          DEPLOY_TMPDIR=$(mktemp -d)
          chmod 700 "$DEPLOY_TMPDIR"
          trap 'rm -rf "$DEPLOY_TMPDIR"' EXIT

          # Set bulk key path so the pass wrapper can lazily extract it
          # on the first actual decryption (if any secrets need uploading).
          export PASS_BULK_KEY_FILE="$DEPLOY_TMPDIR/bulk-key"

          # Sync password store before deploy
          pass git pull --rebase

          # Deploy
          clan machines update "$@"

          # Push any secret changes after deploy
          pass git push
        '';
      };
    };
}
