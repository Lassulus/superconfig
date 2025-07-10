{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.gh-act = pkgs.writeShellApplication {
        name = "gh-act";
        runtimeInputs = with pkgs; [
          yq
          coreutils
        ];
        text = ''
          workflow="''${1:-.github/workflows/ci.yml}"

          if [ ! -f "$workflow" ]; then
            echo "Usage: gh-act [workflow.yml]"
            echo "Run GitHub Actions workflow steps locally"
            exit 1
          fi

          echo "Running: $workflow"
          echo "=================="

          # Extract each step and run it
          for job in $(yq -r '.jobs | keys[]' "$workflow"); do
            echo "=== Job: $job ==="
            step_count=$(yq -r ".jobs[\"$job\"].steps | length" "$workflow")
            for i in $(seq 0 $((step_count - 1))); do
              name=$(yq -r ".jobs[\"$job\"].steps[$i].name // \"Step $i\"" "$workflow")
              run_cmd=$(yq -r ".jobs[\"$job\"].steps[$i].run // empty" "$workflow")
              
              if [ -n "$run_cmd" ]; then
                echo ">>> Running: $name"
                echo "---"
                bash -c "$run_cmd"
                echo
              fi
            done
          done
        '';
      };
    };
}
