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
      # --dashboard` announces the session over the dashboard's keyless REST API
      # (name + collab links, heartbeat + pane push), so it shows up in the
      # covibe.lassul.us overview just like a session started locally on
      # neoprism, and is joinable / browser-viewable via the collab relay. The
      # dashboard GCs the announcement once the session exits.
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

            exec ${covibe}/bin/covibe session \
              --dashboard "$dashboard" \
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
