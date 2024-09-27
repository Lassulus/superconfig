{ pkgs, ... }:
let

  xdg-open = pkgs.writeBashBin "xdg-open" ''
    set -xe
    FILE="$1"
    PATH=/run/current-system/sw/bin
    mime=

    case "$FILE" in
      http://*|https://*)
        mime=text/html
        ;;
      mailto:*)
        mime=special/mailaddress
        ;;
      magnet:*)
        mime=application/x-bittorrent
        ;;
      irc:*)
        mime=x-scheme-handler/irc
        ;;
      *)
        # it’s a file

        # strip possible protocol
        FILE=''${FILE#file://}
        mime=''$(file -E --brief --mime-type "$FILE") \
          || (echo "$mime" 1>&2; exit 1)
          # ^ echo the error message of file
        ;;
    esac

    case "$mime" in
      special/mailaddress)
        alacritty --execute vim "$FILE" ;;
      text/html)
        firefox-devedition "$FILE" ;;
      text/xml)
        firefox-devedition "$FILE" ;;
      text/*)
        alacritty --execute vim "$FILE" ;;
      image/*)
        nsxiv "$FILE" ;;
      application/x-bittorrent)
        env DISPLAY=:0 transgui "$FILE" ;;
      application/pdf)
        zathura "$FILE" ;;
      inode/directory)
        alacritty --execute mc "$FILE" ;;
      inode/symlink)
        exec "$0" "$(realpath "$FILE")" ;;
      audio/*)
        mpv "$FILE" ;;
      video/*)
        mpv "$FILE" ;;
      *)
        echo $TERM >> /tmp/xdg.debug
        # open dmenu and ask for program to open with
        runner=$({ IFS=:; ls -H $PATH; } | sort | dmenu)
        exec $runner "$FILE";;
    esac
  '';
in
{
  environment.systemPackages = [ xdg-open ];
}
