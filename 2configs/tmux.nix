{ config, pkgs, ... }:

{
  environment.etc."tmux.conf".text = ''
    #prefix key to `
    set-option -g prefix2 `

    bind-key r source-file /etc/tmux.conf \; display-message "/etc/tmux.conf reloaded"

    set-option -g default-terminal screen-256color

    #use session instead of windows
    bind-key c new-session
    bind-key p switch-client -p
    bind-key n switch-client -n
    bind-key C-s switch-client -l
  '';
  nixpkgs.config.packageOverrides = super: {
    tmux = pkgs.symlinkJoin {
      name = "tmux";
      paths = [
        (pkgs.writeDashBin "tmux" ''
          exec ${super.tmux}/bin/tmux -f /etc/tmux.conf "$@"
        '')
        super.tmux
      ];
    };
  };
  environment.systemPackages = with pkgs; [
    tmux
  ];

  # programs.bash.interactiveShellInit = ''
  #   if [[ "$TERM" != "linux" && -z "$TMUX" ]]; then
  #     if [[ -n "$SSH_AUTH_SOCK" ]]; then
  #       tmux set-environment -g SSH_AUTH_SOCK "$SSH_AUTH_SOCK" 2>/dev/null
  #     fi

  #     exec tmux -u
  #   fi
  #   if [[ "$__host__" != "$HOST" ]]; then
  #     tmux set -g status-bg colour$(string_hash $HOST 255)
  #     export __host__=$HOST
  #   fi
  # '';
}
