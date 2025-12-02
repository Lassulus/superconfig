{ pkgs, ... }:

pkgs.writeScriptBin "urban" ''
  #!/bin/sh
  set -euf
  term=$1
  curl -LsS 'http://www.urbandictionary.com/define.php?term='"$term" \
    | sed 's/<\/\?a\>[^>]*>//g' \
    | sed 's/<\([^>]*\)>/\n<\1\n/g' \
    | grep . \
    | sed -n '/<div class=.meaning./,/<\/div/p' \
    | sed 's/<div class=.meaning./-----/' \
    | grep -v '^</div\>' \
    | grep -v '^<br\>' \
    | sed '
      s/&quot;/"/g
      s/&#39;/'\'''/g
      s/&gt;/>/g
      s/&lt;/>/g
    '
''
