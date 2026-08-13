{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      self',
      system,
      ...
    }:
    let
      server = "https://omni.lassul.us";
      omp = inputs.llm-agents.packages.${system}.omp;

      # The agent this machine runs. omp speaks the Agent Client Protocol
      # (`omp acp`), so omnigent's generic `acp` harness drives it with no
      # adapter code. The command is the absolute store path because the spec
      # is consumed by the runner started here, and that path is in this
      # wrapper's closure — unlike the server-side catalog entry in
      # 2configs/omnigent.nix, which has to stay unqualified.
      #
      # os_env is what unlocks the dashboard's file panel: without it the
      # runner reports no OS environment and the changed-files/diff endpoints
      # 404. sandbox none because omp needs its own ~/.omp credential store and
      # unrestricted egress to the model APIs; confinement, if we want it, has
      # to happen a layer down (a separate uid, or nspawn), not here.
      spec = pkgs.writeText "omp-agent.yaml" ''
        name: omp
        prompt: You are omp (Oh My Pi), a concise coding assistant.

        executor:
          harness: acp
          acp_agent:
            name: Oh My Pi
            command: ${omp}/bin/omp acp

        os_env:
          type: caller_process
          cwd: "."
          sandbox:
            type: none
      '';
    in
    {
      # Launch omp as a session on the omni.lassul.us dashboard: the agent and
      # its runner stay on this machine (local runner + remote server
      # topology), while the server holds the transcript, the diff view and the
      # per-session ACLs, so a session can be shared read-only or read-write
      # with another pocket-id account. The terminal REPL and the browser drive
      # the same session.
      #
      # First use per machine opens a browser for the pocket-id login; the
      # session JWT is cached in ~/.omnigent/auth_tokens.json afterwards.
      # Arguments go to `omnigent run`, so `covibe -p "fix the tests"` runs one
      # non-interactive turn and `covibe --fork <session-id>` continues someone
      # else's session here.
      packages.covibe =
        (pkgs.writeShellApplication {
          name = "covibe";
          runtimeInputs = [
            self'.packages.omnigent
            omp
            pkgs.jq
            pkgs.git
          ];
          text = ''
            server=${server}
            tokens="$HOME/.omnigent/auth_tokens.json"
            if ! jq -e --arg s "$server" '.[$s].token // empty' "$tokens" >/dev/null 2>&1; then
              echo "covibe: no session for $server yet, logging in" >&2
              omnigent login "$server"
            fi
            exec omnigent run ${spec} --server "$server" "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
