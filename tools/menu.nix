{ ... }:
{
  perSystem =
    { pkgs, ... }:
     {
      packages.menu =
        if pkgs.stdenv.hostPlatform.isDarwin then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.choose-gui
              pkgs.fzf
            ];
            text = ''
              set -efu

              # Create temporary files for input and output
              TEMP_DIR=$(mktemp -d)
              INPUT_FILE="$TEMP_DIR/input"
              OUTPUT_FILE="$TEMP_DIR/output"

              # Set up trap to clean up temp dir on exit
              trap 'rm -rf "$TEMP_DIR"' EXIT

              # Save stdin to file
              cat > "$INPUT_FILE"

              # Try fzf first with terminal UI - explicitly store exit code
              # This avoids issues with losing the exit code in a pipe
              set +e
              fzf "$@" < "$INPUT_FILE" > "$OUTPUT_FILE" 2>/dev/null
              FZF_EXIT=$?
              set -e

              # Handle fzf results based on exit code
              if [ $FZF_EXIT -eq 0 ]; then
                # Success - output result and exit
                cat "$OUTPUT_FILE"
                exit 0
              elif [ $FZF_EXIT -eq 130 ]; then
                # User pressed Escape - honor the cancellation
                exit 130
              fi

              # If we get here, fzf failed with error (not cancellation)

              # Fall back to GUI
              choose "$@" < "$INPUT_FILE"
            '';
          })
        else if pkgs.stdenv.hostPlatform.isLinux then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.rofi
              pkgs.wofi
              pkgs.fzf
            ];
            text = ''
              set -efu
              # Create temporary files for input and output
              TEMP_DIR=$(mktemp -d)
              INPUT_FILE="$TEMP_DIR/input"
              OUTPUT_FILE="$TEMP_DIR/output"

              # Save stdin to file
              cat > "$INPUT_FILE"

              # Try fzf first with terminal UI - explicitly store exit code
              # This avoids issues with losing the exit code in a pipe
              set +e
              fzf "$@" < "$INPUT_FILE" > "$OUTPUT_FILE" 2>/dev/null
              FZF_EXIT=$?
              set -e

              # Handle fzf results based on exit code
              if [ $FZF_EXIT -eq 0 ]; then
                # Success - output result and exit
                cat "$OUTPUT_FILE"
                exit 0
              elif [ $FZF_EXIT -eq 130 ]; then
                # User pressed Escape - honor the cancellation
                exit 130
              fi

              # If we get here, fzf failed with error (not cancellation)

              # Fall back to GUI based on available display environment
              if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
                wofi -d "$@" < "$INPUT_FILE"
              elif [ -n "''${DISPLAY:-}" ]; then
                rofi -dmenu "$@" < "$INPUT_FILE"
              else
                echo "Error: No suitable display environment available" >&2
                exit 1
              fi
            '';
          })
        else
          throw "unsupported system";
    };
}
