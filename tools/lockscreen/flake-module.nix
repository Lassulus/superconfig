{
  perSystem =
    { pkgs, ... }:
    {
      packages.lockscreen =
        (pkgs.writeShellApplication {
          name = "lockscreen";
          runtimeInputs = [
            pkgs.ffmpeg
            pkgs.coreutils
            pkgs.procps
            pkgs.swaylock-plugin
            pkgs.mpvpaper
          ];
          text = ''
            VIDEO=$(find "$HOME"/lockscreens/*.{mp4,webm} | shuf -n 1)
            DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null | cut -d. -f1)
            START=$((RANDOM % ''${DURATION:-300}))
            exec swaylock-plugin --command "mpvpaper -o \"no-audio loop start=$START\" '*' \"$VIDEO\"" "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
