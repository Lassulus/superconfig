{
  perSystem =
    { pkgs, ... }:
    {
      packages.lockscreen = pkgs.writeShellApplication {
        name = "lockscreen";
        runtimeInputs = [
          pkgs.ffmpeg
          pkgs.coreutils
          pkgs.swaylock-plugin
          pkgs.mpvpaper
        ];
        text = ''
          VIDEO=$(shuf -n1 -e "$HOME"/lockscreens/*.mp4)
          DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null | cut -d. -f1)
          START=$((RANDOM % ''${DURATION:-300}))
          exec swaylock-plugin --command "mpvpaper -o \"no-audio loop start=$START\" '*' \"$VIDEO\"" "$@"
        '';
      };
    };
}
