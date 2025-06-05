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
            ];
            text = ''
              set -efu
              # TODO check if a terminal is available and use fzf in that case
              exec choose "$@"
            '';
          })
        else if pkgs.stdenv.hostPlatform.isLinux then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.rofi
              pkgs.wofi
            ];
            text = ''
              set -efu
              # TODO check if a terminal is available and use fzf in that case
              if [[ -n $WAYLAND_DISPLAY ]]; then
                exec wofi "$@"
              elif [[ -n $DISPLAY ]]; then
                exec rofi "$@"
              fi
            '';

          })
        else
          throw "unsupported system";
    };
}
