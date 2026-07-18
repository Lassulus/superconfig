{
  perSystem =
    { pkgs, ... }:
    {
      packages.wallpaper =
        (pkgs.writeShellApplication {
          name = "wallpaper";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.mpvpaper
          ];
          text = ''
            # Pick a random wallpaper (video or image) from ~/wallpaper and
            # render it on every output via mpvpaper. Long-running: this
            # process *is* the wallpaper. `-p` auto-pauses playback while the
            # wallpaper is fully hidden to save power.
            FILE=$(find "$HOME/wallpaper" -type f \( \
              -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o \
              -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \
              \) 2>/dev/null | shuf -n 1)
            if [ -z "$FILE" ]; then
              echo "wallpaper: no wallpapers found in ~/wallpaper" >&2
              exit 0
            fi
            exec mpvpaper -p \
              -o "no-audio loop-file=inf image-display-duration=inf hwdec=auto-safe msg-level=all=no" \
              '*' "$FILE"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
