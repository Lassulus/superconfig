{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.tui-stream-server = pkgs.writeShellApplication {
        name = "tui-stream-server";
        runtimeInputs = [
          pkgs.ffmpeg
          pkgs.wf-recorder # Wayland screen capture
          pkgs.wlr-randr # Wayland resolution detection
          pkgs.xorg.xdpyinfo # X11 resolution detection
        ];
        text = builtins.readFile ./server.sh;
      };

      packages.tui-stream-client = pkgs.writeShellApplication {
        name = "tui-stream-client";
        runtimeInputs = [
          pkgs.mpv # Default player
        ];
        text = builtins.readFile ./client.sh;
      };

      # Combined package with both server and client
      packages.tui-stream = pkgs.symlinkJoin {
        name = "tui-stream";
        paths = [
          pkgs.writeShellApplication {
            name = "tui-stream-server";
            runtimeInputs = [
              pkgs.ffmpeg
              pkgs.wf-recorder
              pkgs.wlr-randr
              pkgs.xorg.xdpyinfo
            ];
            text = builtins.readFile ./server.sh;
          }
          pkgs.writeShellApplication {
            name = "tui-stream-client";
            runtimeInputs = [
              pkgs.mpv
            ];
            text = builtins.readFile ./client.sh;
          }
        ];
      };
    };
}
