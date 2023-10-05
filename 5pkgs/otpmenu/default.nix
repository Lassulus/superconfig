{ pkgs }:
pkgs.writers.writeDashBin "otpmenu" ''
set -efux
x=$(${pkgs.pass}/bin/pass git ls-files '*/otp.gpg' \
  | ${pkgs.gnused}/bin/sed 's:/otp\.gpg$::' \
  | ${pkgs.dmenu}/bin/dmenu
)

otp=$(${(pkgs.pass.withExtensions (ext: [ ext.pass-otp ]))}/bin/pass otp code "$x/otp")
printf %s "$otp" | ${pkgs.wtype}/bin/wtype -s 1 - || printf %s "$otp" | ${pkgs.xdotool}/bin/xdotool type -f -
''
