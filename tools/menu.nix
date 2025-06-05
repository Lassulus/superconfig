{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # Function to detect if we're running in a terminal environment
      terminalDetectionFunction = ''
        is_terminal_environment() {
          # Check if we're running in a TTY
          if [ -t 0 ] || [ -t 1 ]; then
            return 0  # True, we're in a terminal
          fi
          
          # Check if our parent process is a terminal
          parent_process=$(ps -o comm= $PPID 2>/dev/null || true)
          terminal_programs="bash zsh fish sh ksh csh tcsh dash xterm konsole gnome-terminal alacritty kitty terminal terminator urxvt rxvt xfce4-terminal iterm2 Terminal"
          for term in $terminal_programs; do
            if echo "$parent_process" | grep -q "$term"; then
              return 0  # True, parent is a terminal
            fi
          done
          
          # Check if we're in an interactive environment
          if [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
            # Check if we're in an SSH session
            if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
              return 0  # True, SSH session implies terminal
            fi
          fi
          
          return 1  # False, not in a terminal
        }
      '';
    in
    {
      packages.menu =
        if pkgs.stdenv.hostPlatform.isDarwin then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.choose-gui
              pkgs.fzf
              pkgs.procps
            ];
            text = ''
              set -efu
              
              # Terminal detection function
              ${terminalDetectionFunction}
              
              # Decide which menu program to use
              if is_terminal_environment; then
                # Use terminal-based menu
                cat | fzf "$@"
              else
                # Use GUI-based menu
                cat | choose "$@"
              fi
            '';
          })
        else if pkgs.stdenv.hostPlatform.isLinux then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.rofi
              pkgs.wofi
              pkgs.fzf
              pkgs.procps
            ];
            text = ''
              set -efu
              
              # Terminal detection function
              ${terminalDetectionFunction}
              
              # Decide which menu program to use
              if is_terminal_environment; then
                # Use terminal-based menu
                cat | fzf "$@"
              elif [[ -n $WAYLAND_DISPLAY ]]; then
                # Use wofi in Wayland
                cat | wofi -d "$@"
              elif [[ -n $DISPLAY ]]; then
                # Use rofi in X11
                cat | rofi -dmenu "$@"
              else
                # No terminal or GUI environment, fallback to fzf
                cat | fzf "$@"
              fi
            '';

          })
        else
          throw "unsupported system";
    };
}
