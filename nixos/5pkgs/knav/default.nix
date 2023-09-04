{ pkgs, ... }: let

  keynavrc = pkgs.writeText "keynavrc" ''
    clear
    Escape quit
    q record ~/.keynav_macros
    shift+at playback
    u history-back
    a cut-left
    s cut-down
    w cut-up
    d cut-right
    shift+a move-left
    shift+s move-down
    shift+w move-up
    shift+d move-right
    t windowzoom
    c cursorzoom 300 300
    e warp
    1 click 1
    2 click 2
    3 click 3
  '';
in pkgs.writeScriptBin "knav" ''
  ${pkgs.keynav}/bin/keynav "loadconfig ${keynavrc}, start"
''
