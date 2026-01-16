{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      ffmpeg-placebo = pkgs.ffmpeg.override { withPlacebo = true; };
    in
    {
      packages.android-webcam = pkgs.writeShellApplication {
        name = "android-webcam";
        runtimeInputs = [
          pkgs.scrcpy
          ffmpeg-placebo
          pkgs.kmod
        ];
        text = builtins.replaceStrings
          [ "@shaderPath@" ]
          [ "${./ascii.hook}" ]
          (builtins.readFile ./android-webcam.sh);
      };
    };
}
