{ ... }:
{
  perSystem =
    { pkgs, self', ... }:
    {
      packages.record = pkgs.writeShellApplication {
        name = "record";
        runtimeInputs = [
          pkgs.ffmpeg
          pkgs.gum
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.pulseaudio ]
        ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ self'.packages.system-audio-dump ];
        text = builtins.readFile ./rec.sh;
      };
    };
}
