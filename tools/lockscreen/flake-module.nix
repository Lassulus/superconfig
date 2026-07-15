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
            # Random lock background (video or image) from the shared
            # ~/wallpaper folder. Falls back to a plain locker when the
            # folder is empty, so the screen still locks.
            FILE=$(find "$HOME/wallpaper" -type f \( \
              -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o \
              -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \
              \) 2>/dev/null | shuf -n 1 || true)
            if [ -z "$FILE" ]; then
              exec swaylock-plugin "$@"
            fi
            DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FILE" 2>/dev/null | cut -d. -f1)
            case "$DUR" in "" | *[!0-9]*) DUR=1 ;; esac
            if [ "$DUR" -lt 1 ]; then DUR=1; fi
            START=$((RANDOM % DUR))
            exec swaylock-plugin --command "mpvpaper -o \"no-audio loop start=$START\" '*' \"$FILE\"" "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
