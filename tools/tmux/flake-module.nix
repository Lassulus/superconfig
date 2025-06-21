{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      tmuxConfigText = ''
        set-option -g default-terminal screen-256color

        # Auto-destroy sessions when no clients attached (handles terminal close)
        set -g destroy-unattached on
      '';
      tmuxConfigFile = pkgs.writeText "tmux.conf" tmuxConfigText;
    in
    {
      packages.tmux =
        (self.libWithPkgs.${system}.makeWrapper pkgs.tmux {
          wrapper = ''
            exec ${pkgs.lib.getExe pkgs.tmux} -f ${tmuxConfigFile} "$@"
          '';
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              tmuxConfig = tmuxConfigText;
            };
          });
    };
}
