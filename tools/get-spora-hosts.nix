{ self, ... }:
{
  perSystem = { system, pkgs, ... }: {
    packages.get-spora-hosts = pkgs.writeScriptBin "get-spora-hosts" ''
      set -eu
      set -o pipefail
      set -x
      OUTDIR=$1
      for host in ${self}/machines/*; do
        if test -e "$host"/facts/mycelium_pubkey; then
          if ! test -e "$OUTDIR"/"$(basename "$host")".json; then
            ${self.packages.${pkgs.system}.mycelium}/bin/mycelium inspect "$(cat "$host"/facts/mycelium_pubkey)" --json > "$OUTDIR/$(basename "$host").json"
          fi
        fi
      done
    '';
  };
}
