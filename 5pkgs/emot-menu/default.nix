{ coreutils, dmenu, gnused, writers, writeText, xdotool }: let

  emoticons = writeText "emoticons" ''
¯\(°_o)/¯ | dunno lol shrug dlol
¯\_(ツ)_/¯ | dunno lol shrug dlol
( ͡° ͜ʖ ͡°) | lenny
¯\_( ͡° ͜ʖ ͡°)_/¯ | lenny shrug dlol
( ﾟдﾟ) | aaah sad noo
ヽ(^o^)丿 | hi yay hello
(^o^; | ups hehe
(^∇^) | yay
┗(｀皿´)┛ | angry argh
ヾ(^_^) byebye!! | bye
<(^.^<) <(^.^)> (>^.^)> (7^.^)7 (>^.^<) | dance
(-.-)Zzz... | sleep
(∩╹□╹∩) | oh noes woot
™ | tm
ζ | zeta
(╯°□°）╯ ┻━┻ | table flip
(」゜ロ゜)」 | why woot
(_゜_゜_) | gloom I see you
༼ ༎ຶ ෴ ༎ຶ༽ | sad
(\/) (°,,,,°) (\/) | krebs
  '';

in
writers.writeDashBin "emoticons" ''
  set -efu

  data=$(${coreutils}/bin/cat ${emoticons})
  emoticon=$(echo "$data" | ${dmenu}/bin/dmenu | ${gnused}/bin/sed 's/ | .*//')
  ${xdotool}/bin/xdotool type --clearmodifiers -- "$emoticon"
  exit 0
''
