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
            text = builtins.readFile ./menu-darwin.sh;
          })
        else if pkgs.stdenv.hostPlatform.isLinux then
          (pkgs.writeShellApplication {
            name = "menu";
            runtimeInputs = [
              pkgs.rofi
              pkgs.wofi
              pkgs.fzf
            ];
            text = builtins.readFile ./menu-linux.sh;
          })
        else
          throw "unsupported system";
    };
}
