{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      tmuxConfigText = ''
        set-option -g default-terminal screen-256color

        # Auto-destroy sessions when no clients attached (handles terminal close)
        set -g destroy-unattached on

        # Enable kitty graphics protocol passthrough
        set -g allow-passthrough on
        set -ga update-environment TERM
        set -ga update-environment TERM_PROGRAM
      '';
      tmuxConfigFile = pkgs.writeText "tmux.conf" tmuxConfigText;
    in
    {
      packages.tmux =
        (self.wrapLib.makeWrapper {
          pkgs = pkgs;
          package = pkgs.tmux;
          flags = {
            "-f" = tmuxConfigFile;
          };
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              tmuxConfig = tmuxConfigText;
            };
          });
    };
}
