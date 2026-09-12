{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # Start an omp agent in a new herdr tab from one command:
      #   s herd 'fix issue #13' --model opus
      # Everything is passed through to omp, so any omp flag works. The tab
      # lands in the focused workspace (one is created from $PWD if there is
      # none) and is not focused, so the caller's pane stays put. herdr picks
      # the agent up by itself; name it with `herdr agent rename <pane> <name>`
      # if you want to address it by name afterwards.
      packages.herd =
        (pkgs.writeShellApplication {
          name = "herd";
          runtimeInputs = [
            inputs.llm-agents.packages.${system}.herdr
            pkgs.jq
          ];
          text = ''
            workspace=''${HERDR_WORKSPACE_ID:-$(herdr workspace list | jq -r '.result.workspaces[] | select(.focused) | .workspace_id')}
            label=$(printf '%s' "''${1:-omp}" | cut -c1-32)
            if [ -n "$workspace" ]; then
              created=$(herdr tab create --workspace "$workspace" --cwd "$PWD" --label "$label" --no-focus)
            else
              created=$(herdr workspace create --cwd "$PWD" --label "$(basename "$PWD")" --no-focus)
            fi
            pane=$(printf '%s' "$created" | jq -er .result.root_pane.pane_id)
            herdr pane run "$pane" "s llm.omp$(printf ' %q' "$@")" >/dev/null
            echo "$pane"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
