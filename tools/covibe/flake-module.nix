{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      # Launch omp as a co-vibing session from any machine: `covibe` in a project
      # directory announces the session over the dashboard's keyless REST API
      # (name + collab links, heartbeat + pane push), so it shows up in the
      # covibe.lassul.us overview just like a session started locally on
      # neoprism, and is joinable / browser-viewable via the collab relay. The
      # dashboard GCs the announcement once the session exits.
      #
      # The package, the patched omp and the wrapping all come from the covibe
      # flake; only the deployment addresses live here. Arguments go to omp, so
      # `covibe --continue` resumes in the current directory.
      packages.covibe =
        (inputs.covibe.packages.${system}.covibe-client.override {
          dashboard = "https://covibe.lassul.us";
          relayHost = "covibe.lassul.us";
          webClient = "https://covibe.lassul.us/c";
          localRelay = "wss://covibe.lassul.us";
          defaultArgs = [
            "session"
            "--"
          ];
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
