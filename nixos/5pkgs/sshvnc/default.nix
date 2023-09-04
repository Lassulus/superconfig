{ pkgs }:
pkgs.writers.writeBashBin "sshvnc" ''
  set -xm

  RANDOM_HIGH_PORT=$(shuf -i 20000-65000 -n 1)
  ssh "$@" -f -L $RANDOM_HIGH_PORT:localhost:$RANDOM_HIGH_PORT -- x11vnc -noxdamage -noxfixes -noxrecord -display :0 -localhost -rfbport $RANDOM_HIGH_PORT

  sleep 3

  _JAVA_AWT_WM_NONREPARENTING=1 ${pkgs.turbovnc}/bin/vncviewer localhost:$RANDOM_HIGH_PORT
''
