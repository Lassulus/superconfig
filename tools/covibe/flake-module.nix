{ self, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Client omp carrying covibe's env-driven headless collab autostart
      # (OMP_COLLAB_*) -- the exact patch the neoprism covibe service uses, so a
      # session hosts natively against the covibe relay. `covibe session` mints
      # the room and passes OMP_COLLAB_* to this omp.
      ompCollab = self.legacyPackages.${system}.llm.omp.overrideAttrs (o: {
        patches = (o.patches or [ ]) ++ [ ../../2configs/omp-collab-autostart.patch ];
      });
      covibe = inputs.covibe.packages.${system}.covibe;
    in
    {
      # Launch omp as a co-vibing session from any machine: `covibe session
      # --dashboard` registers the session over the dashboard's REST API (with
      # heartbeat + pane push), so it shows up in the covibe.lassul.us overview
      # just like a session started locally on neoprism, and is joinable /
      # browser-viewable via the collab relay.
      packages.covibe =
        (pkgs.writeShellApplication {
          name = "covibe";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            dashboard="''${COVIBE_DASHBOARD:-https://covibe.lassul.us}"
            relay="''${COVIBE_LOCAL_RELAY:-wss://covibe.lassul.us}"
            web="''${COVIBE_WEB_CLIENT:-https://covibe.lassul.us/c}"
            host="''${COVIBE_RELAY_HOST:-covibe.lassul.us}"
            name="''${COVIBE_NAME:-$(basename "$PWD")}"

            # Dashboard API key: env, else the password store, else bail.
            api_key="''${COVIBE_API_KEY:-}"
            if [ -z "$api_key" ] && command -v pass >/dev/null 2>&1; then
              api_key="$(pass show covibe/api-key 2>/dev/null || true)"
            fi
            if [ -z "$api_key" ]; then
              echo "covibe: no API key. Set COVIBE_API_KEY or add 'covibe/api-key' to pass." >&2
              exit 1
            fi

            exec ${covibe}/bin/covibe session \
              --dashboard "$dashboard" \
              --api-key "$api_key" \
              --relay-host "$host" \
              --web-client "$web" \
              --local-relay "$relay" \
              --omp ${ompCollab}/bin/omp \
              --name "$name" \
              --dir "$PWD" \
              -- "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
