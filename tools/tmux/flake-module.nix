{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      sessionManager = pkgs.writeShellScript "tmux-session-manager" ''
        while true; do
          existing=$(tmux list-sessions -F '#{session_name}: #{session_windows} windows (created #{session_created_string})#{?session_attached, (attached),}' 2>/dev/null)
          [[ -z "$existing" ]] && break
          chosen=$(echo -e ">>> new session <<<\n$existing" \
            | ${pkgs.fzf}/bin/fzf --height=80% --reverse \
                  --header="Pick a tmux session (DEL to kill)" \
                  --expect=delete \
                  --preview='s={1}; s=''${s%:}; [ "$s" = ">>>" ] && echo "Create a new session" || tmux capture-pane -t "$s" -p -e 2>/dev/null' \
                  --preview-window=down:50%)
          key=$(echo "$chosen" | head -1)
          selection=$(echo "$chosen" | tail -1)
          chosen_name=$(echo "$selection" | cut -d: -f1)
          if [[ "$key" == "delete" && -n "$chosen_name" && "$chosen_name" != ">>> new session <<<" ]]; then
            tmux kill-session -t "$chosen_name" 2>/dev/null
            continue
          fi
          if [[ -n "$chosen_name" && "$chosen_name" != ">>> new session <<<" ]]; then
            tmux switch-client -t "$chosen_name"
            exit 0
          fi
          break
        done
        # Create a new session
        session_name=$(${
          self.packages.${pkgs.system}.name-generator
        }/bin/name-generator 2>/dev/null || echo "session-$$")
        tmux new-session -d -s "$session_name"
        tmux switch-client -t "$session_name"
      '';
      tmuxConfigText = ''
        set-option -g default-terminal screen-256color

        # Enable extended keys (CSI u / modified key sequences)
        set -s extended-keys on
        set -as terminal-features 'xterm*:extkeys'

        # Enable kitty graphics protocol passthrough
        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM

        # Session manager popup (prefix + s)
        bind s display-popup -E -w 80% -h 80% "${sessionManager}"
        # tmux 3.7 stopped entering copy-mode on wheel/drag over alternate-screen
        # panes and forwards the events to the app instead (issue 3705), which
        # breaks scrolling around omp's fullscreen overlays. Pin the 3.6
        # behavior: only hand the mouse to apps that track it themselves.
        bind -n WheelUpPane { if -F '#{||:#{pane_in_mode},#{mouse_any_flag}}' { send -M } { copy-mode -e } }
        bind -n MouseDrag1Pane { if -F '#{||:#{pane_in_mode},#{mouse_any_flag}}' { send -M } { copy-mode -M } }
      '';
      tmuxConfigFile = pkgs.writeText "tmux.conf" tmuxConfigText;
    in
    {
      packages.tmux =
        (inputs.wrappers.lib.wrapPackage {
          pkgs = pkgs;
          package = pkgs.tmux;
          flags = {
            "-f" = "${tmuxConfigFile}";
          };
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              tmuxConfig = tmuxConfigText;
            };
          });
    };
}
