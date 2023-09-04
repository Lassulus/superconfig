{ pkgs, ... }:

pkgs.writeScriptBin "yt-next" ''
  #! ${pkgs.bash}/bin/bash

  vid=$1
  num=''${NUM:-1}

  curl -Ls $1 \
  | grep 'href="/watch?v=' \
  | head -n$num \
  | sed 's,.*href="\([^"]*\)".*,https://youtube.com\1,'
''
