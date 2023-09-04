{ config, pkgs, lib, ... }: let

  xdg-open-wrapper = pkgs.writeDashBin "xdg-open" ''
     exec ${xdg-open}/bin/xdg-open "$@" >> /tmp/xdg-debug.log 2>&1
  '';

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
        firefox "$FILE" ;;
      text/xml)
        firefox "$FILE" ;;
      text/*)
        alacritty --execute vim "$FILE" ;;
      image/*)
        sxiv "$FILE" ;;
      application/x-bittorrent)
        env DISPLAY=:0 transgui "$FILE" ;;
      application/pdf)
        zathura "$FILE" ;;
      inode/directory)
        alacritty --execute mc "$FILE" ;;
      *)
        # open dmenu and ask for program to open with
        runner=$(print -rC1 -- ''${(ko)commands} | dmenu)
        exec $runner "$FILE";;
    esac
  '';
in {
  environment.systemPackages = [ xdg-open-wrapper ];

  security.sudo.extraConfig = ''
    cr ALL=(lass) NOPASSWD: ${xdg-open}/bin/xdg-open *
    ff ALL=(lass) NOPASSWD: ${xdg-open}/bin/xdg-open *
  '';
}
