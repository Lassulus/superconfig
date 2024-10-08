{ pkgs }:
pkgs.writers.writeDashBin "otpmenu" ''
  set -efux
  x=$(${pkgs.pass}/bin/pass git ls-files '*/otp.gpg' \
    | ${pkgs.gnused}/bin/sed 's:/otp\.gpg$::' \
    | ${pkgs.rofi}/bin/rofi -dmenu
  )

  otp=$(${(pkgs.pass.withExtensions (ext: [ ext.pass-otp ]))}/bin/pass otp code "$x/otp")
  printf %s "$otp" | ${pkgs.wtype}/bin/wtype -d 10 -s 200 - || printf %s "$otp" | ${pkgs.xdotool}/bin/xdotool type -f -
''
