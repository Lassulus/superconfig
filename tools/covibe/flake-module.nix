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

      # omnigent's `pi-native` harness runs the agent's own TUI in a tmux pane,
      # attaches your TTY to it, and mirrors the session (transcript, tool
      # calls, terminal, files) to the server — the shape covibe always had,
      # now with omnigent's per-session ACLs behind it. It resolves the CLI by
      # the literal name `pi` (onboarding/harness_install.py: the readiness gate
      # is `resolve_cli_binary("pi")`, which ignores OMNIGENT_PI_PATH and the
      # config override), so omp has to reach it under that name. Version-gated
      # flags are satisfied by omp reporting 17.x >= pi's declared 0.79.0 floor.
      piShim = pkgs.writeShellApplication {
        name = "pi";
        text = ''
          OMP_BIN=${omp}/bin/omp
        ''
        + builtins.readFile ./pi-shim.sh;
      };
    in
    {
      # Launch omp as a session on the omni.lassul.us dashboard: omp's own TUI
      # runs here, in a tmux pane owned by the local runner, while the server
      # holds the transcript, the diff view and the per-session ACLs — so a
      # session can be shared read-only or read-write with another pocket-id
      # account, and a teammate's message from the browser executes in this
      # TUI.
      #
      # First use per machine opens a browser for the pocket-id login; the
      # session JWT is cached in ~/.omnigent/auth_tokens.json afterwards.
      # Arguments go through to omp, e.g. `covibe --continue`; `covibe --resume`
      # (no value) opens omnigent's session picker.
      packages.covibe =
        (pkgs.writeShellApplication {
          name = "covibe";
          runtimeInputs = [
            self'.packages.omnigent
            piShim
            pkgs.tmux
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
            exec omnigent pi --server "$server" "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
