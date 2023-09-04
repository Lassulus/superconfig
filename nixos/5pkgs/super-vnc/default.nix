{ pkgs, lib }: let

  quoteChar = c:
    if c == "\n" then "'\n'"
    else c;
  quote = x: if x == "" then "''" else lib.stringAsChars quoteChar x;

in pkgs.writers.writeDashBin "super-vnc" ''
  PATH=${lib.makeBinPath (with pkgs; [
    xorg.xrandr gnugrep coreutils xorg.xorgserver gnused openssh gawk tightvnc
  ])}
  remote=$1
  res_x=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f1)
  res_y=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f2)
  export modeline="$(gtf "$res_x" "$res_y" 60 | sed -n 's/.*Modeline "\([^" ]\+\)" \(.*\)/\1 \2/p')"
  export name="$(echo "$modeline" | sed 's/\([^ ]\+\) .*/\1/')"
  export vncline="''${res_x}x''${res_y}+0+0"

  if [ -z "$modeline" -o -z "$name" ]; then
    echo "Error! modeline=$modeline name=$name"
    exit 1
  fi

  echo $modeline

  # TODO user random highport
  ssh "$remote" -L 5900:localhost:55900 bash <<EOF
set -x
export DISPLAY=:0
export output=\$(xrandr | grep disconnected | tail -1 | cut -d' ' -f1)
xrandr --newmode $modeline
xrandr --verbose --addmode "\$output" "$name"
xrandr --output "\$output" --off
xrandr --verbose --output "\$output" --mode "$name" --right-of "\$(xrandr | grep primary | cut -d ' ' -f1)"
EOF
  sleep 2
  vncviewer localhost:55900
''
