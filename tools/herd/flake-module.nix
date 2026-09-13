{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # Start an omp agent in a new herdr tab from one command:
      #   s herd 'fix issue #13' --model opus
      # Everything is passed through to omp, so any omp flag works. The tab
      # lands in the focused workspace (one is created from $PWD if there is
      # none). By default it is not focused, so the caller's pane stays put;
      # `-f`/`--focus` (before the prompt) switches to the new pane instead.
      # herdr picks the agent up by itself; name it with
      # `herdr agent rename <pane> <name>` if you want to address it by name
      # afterwards.
      packages.herd =
        (pkgs.writeShellApplication {
          name = "herd";
          runtimeInputs = [
            inputs.llm-agents.packages.${system}.herdr
            pkgs.jq
          ];
          text = ''
            focus=--no-focus
            case "''${1:-}" in
            -f|--focus)
              focus=--focus
              shift
              ;;
            esac
            # Not $HERDR_WORKSPACE_ID: that is the launch-time value and goes
            # stale once the pane is moved to another workspace (herdr keeps
            # the old pane id as an alias, so `pane current` still resolves).
            workspace=$(herdr pane current 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
            [ -n "$workspace" ] || workspace=$(herdr workspace list | jq -r '.result.workspaces[] | select(.focused) | .workspace_id')
            label=$(printf '%s' "''${1:-omp}" | cut -c1-32)
            if [ -n "$workspace" ]; then
              created=$(herdr tab create --workspace "$workspace" --cwd "$PWD" --label "$label" "$focus")
            else
              created=$(herdr workspace create --cwd "$PWD" --label "$(basename "$PWD")" "$focus")
            fi
            pane=$(printf '%s' "$created" | jq -er .result.root_pane.pane_id)
            herdr pane run "$pane" "s llm.omp$(printf ' %q' "$@")" >/dev/null
            echo "$pane"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
