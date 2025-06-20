{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      tmuxConfigText = ''
        set-option -g default-terminal screen-256color

        # Auto-destroy sessions when no clients attached (handles terminal close)
        set -g destroy-unattached on
      '';
      tmuxConfigFile = pkgs.writeText "tmux.conf" tmuxConfigText;
    in
    {
      packages.tmux = pkgs.symlinkJoin {
        name = "tmux";
        paths = [
          (pkgs.writeShellApplication {
            name = "tmux";
            text = ''
              exec ${pkgs.tmux}/bin/tmux -f ${tmuxConfigFile} "$@"
            '';
          })
          pkgs.tmux
        ];
        passthru = {
          tmuxConfig = tmuxConfigText;
        };
      };
    };
}
