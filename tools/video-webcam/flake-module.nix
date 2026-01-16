{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.video-webcam = pkgs.writeShellApplication {
        name = "video-webcam";
        runtimeInputs = [
          pkgs.ffmpeg
        ];
        text = builtins.readFile ./video-webcam.sh;
      };
    };
}
