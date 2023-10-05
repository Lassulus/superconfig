{ pkgs, ... }:

pkgs.writeScriptBin "mpv-poll" ''
  #! ${pkgs.bash}/bin/bash

  pl=$1
  hist=''${HISTORY:-"./mpv_history"}
  mpv_options=''${MPV_OPTIONS:-""}

  lastYT=""

  play_video () {
    toPlay=$1
    echo $toPlay >> $hist
    mpv $mpv_options $toPlay
  }

  if ! [ -e $hist ]; then
    touch $hist
  fi

  while :
  do
    if [ -s $pl ]; then
      toPlay=$(head -1 $pl)
      sed -i '1d' $pl
      if $(echo $toPlay | grep -Eq 'https?://(www.)?youtube.com/watch'); then
        lastYT=$toPlay
      fi
      play_video $toPlay
    else
      if [ -n "$lastYT" ]; then
        next=$(yt-next $lastYT)
        lastYT=$next
        play_video $next
      fi
      sleep 1
    fi
  done
''
