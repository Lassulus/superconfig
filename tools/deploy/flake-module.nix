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
          DEPLOY_TMPDIR=$(mktemp -d)
          chmod 700 "$DEPLOY_TMPDIR"
          trap 'rm -rf "$DEPLOY_TMPDIR"' EXIT

          export PASS_BULK_KEY_FILE="$DEPLOY_TMPDIR/bulk-key"

          # Sync password store before deploy
          pass git pull --rebase

          # Extract bulk key for fast decryption during deploy
          pass show bulk-operations/age-key > "$PASS_BULK_KEY_FILE" 2>/dev/null || true

          # Deploy
          clan machines update "$@"

          # Push any secret changes after deploy
          pass git push
        '';
      };
    };
}
