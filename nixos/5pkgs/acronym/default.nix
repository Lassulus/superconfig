{ pkgs, ... }:

pkgs.writeScriptBin "acronym" ''

  #! ${pkgs.bash}/bin/bash

  acro=$1

  curl -L -s http://www.acronymfinder.com/$acro.html \
    | grep 'class="result-list__body__rank"' \
    | sed '
      s/.*title="\([^"]*\)".*/\1/
      s/^.* - //
      s/&#39;/'\'''/g
    '
''
