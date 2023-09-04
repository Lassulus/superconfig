{ writeDashBin, writeHaskellPackage, coreutils, xorg, virtualgl, ... }:

let

  xephyrify-xmonad = writeHaskellPackage "xephyrify-xmonad" {
    executables.xmonad = {
      extra-depends = [
        "containers"
        "unix"
        "xmonad"
      ];
      text = /* haskell */ ''
        module Main where
        import XMonad
        import Data.Monoid
        import System.Posix.Process (executeFile)
        import qualified Data.Map as Map

        main :: IO ()
        main = do
          xmonad def
            { workspaces = [ "1" ]
            , layoutHook = myLayoutHook
            , keys = myKeys
            , normalBorderColor  = "#000000"
            , focusedBorderColor = "#000000"
            , handleEventHook = myEventHook
            }

        myEventHook :: Event -> X All

        myEventHook (ConfigureEvent { ev_event_type = 22 }) = do
          spawn "${xorg.xrandr}/bin/xrandr >/dev/null 2>&1"
          return (All True)

        myEventHook _ = do
          return (All True)

        myLayoutHook = Full
        myKeys _ = Map.fromList []
      '';
    };
  };

in writeDashBin "xephyrify" ''
  NDISPLAY=''${NDISPLAY:-$(${coreutils}/bin/shuf -i 100-65536 -n 1)}
  echo "using DISPLAY $NDISPLAY"
  ${xorg.xorgserver}/bin/Xephyr -br -ac -reset -terminate -resizeable -dpi 60 -nolisten local :$NDISPLAY &
  if test -n $DROP_TO_USER; then
    sleep 1
    ls /tmp/.X11-unix/
    id
    ${coreutils}/bin/chgrp "$DROP_TO_USER" "/tmp/.X11-unix/X$NDISPLAY"
    ${coreutils}/bin/chmod 770 "/tmp/.X11-unix/X$NDISPLAY"
  fi
  XEPHYR_PID=$!
  DISPLAY=:$NDISPLAY ${xephyrify-xmonad}/bin/xmonad &
  XMONAD_PID=$!
  DISPLAY=:$NDISPLAY ${virtualgl}/bin/vglrun "$@"
  kill $XMONAD_PID
  kill $XEPHYR_PID
''
