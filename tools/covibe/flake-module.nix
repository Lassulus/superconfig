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
      # Auth is the pocket-id login, but *only a browser* has to see pocket-id —
      # the machine running the agent only needs to reach the server. omnigent's
      # cli-ticket flow (POST /auth/cli-login, then poll /auth/cli-poll for five
      # minutes) prints a URL that any device with your passkey can complete, so
      # this works over ssh on a box with no display: run `covibe login`, open
      # the printed link on a laptop or phone, done. The session JWT is then
      # cached in ~/.omnigent/auth_tokens.json for the server's configured TTL.
      # Other arguments go through to omp, e.g. `covibe --continue`;
      # `covibe --resume` (no value) opens omnigent's session picker.
      #
      # Note the TUI path runs on a spec omnigent materialises itself
      # (`pi-native-ui`), so the only terminal it declares is omp's own pane;
      # extra shells from the dashboard are a property of the *browser-started*
      # omp agent, whose spec lives in 2configs/omnigent.nix.
      packages.covibe =
        (pkgs.writeShellApplication {
          name = "covibe";
          runtimeInputs = [
            self'.packages.omnigent
            piShim
            # The host daemon we spawn inherits this PATH, and sessions started
            # from the *browser* use the server's catalog entry, whose command is
            # a bare `omp acp` resolved here — without omp on PATH those turns
            # die with "inner executor error: [Errno 2] No such file or
            # directory". The `pi` shim alone is not enough: it only covers the
            # pi-native TUI path.
            omp
            pkgs.tmux
            pkgs.jq
            pkgs.git
          ];
          text = ''
            server=${server}
            tokens="$HOME/.omnigent/auth_tokens.json"

            # `webbrowser.open` walks a candidate list that includes terminal
            # browsers; on a headless box one of those can seize the tty we are
            # about to hand to omp's TUI. With no display, make the "open" a
            # no-op — the URL is printed either way.
            if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
              export BROWSER=''${BROWSER:-echo}
            fi

            login() {
              echo "covibe: authenticating against $server" >&2
              echo "covibe: open the link below on any device that has your pocket-id passkey" >&2
              omnigent login "$server"
            }

            case "''${1:-}" in
            login)
              login
              exit 0
              ;;
            host)
              # Register this machine so sessions can also be STARTED from the
              # browser (New Chat → this host → the `omp` agent). That path runs
              # `omp acp` from the runner's PATH, which only has omp when the
              # daemon was spawned with it — as it is here. Runs in the
              # foreground; ^C stops hosting.
              shift
              exec omnigent host "$server" "$@"
              ;;
            esac

            # The cached session is a JWT with a server-side TTL
            # (OMNIGENT_OIDC_SESSION_TTL_HOURS), so "a token exists" is not the
            # same as "we are logged in": a stale entry makes omnigent fail with
            # `Pi session creation failed (401): Authentication required`
            # instead of re-authenticating. Check the recorded expiry (with a
            # minute of slack, via jq's own clock so this needs no coreutils).
            if ! jq -e --arg s "$server" \
                 '((.[$s].expires_at // 0) > (now + 60)) and ((.[$s].token // "") != "")' \
                 "$tokens" >/dev/null 2>&1; then
              login
            fi
            exec omnigent pi --server "$server" "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
