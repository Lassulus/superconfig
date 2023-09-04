{ pkgs }:
pkgs.writers.writeBashBin "dl" ''
  set -efux
  LINK_OR_SEARCH=$@
  if [[ $LINK_OR_SEARCH == magnet:?* ]] || [[ $LINK_OR_SEARCH =~ ^https?: ]]; then
    LINK=$LINK_OR_SEARCH
  else
    SEARCH=$LINK_OR_SEARCH
  fi

  if ! [ -z ''${SEARCH+x} ]; then
    LINK=$(${pkgs.we-get}/bin/we-get -n 50 -t the_pirate_bay,1337x --json -s "$SEARCH" |
      ${pkgs.jq}/bin/jq -r 'to_entries |
        .[] |
        "\(.key) [\(.value.seeds)]\t\(.value.link)"
      ' |
      ${pkgs.fzf}/bin/fzf -d '\t' --with-nth=1 |
      ${pkgs.coreutils}/bin/cut -f 2
    )
  fi

  if [ -z ''${CATEGORY+x} ]; then
    CATEGORY=$(echo -e 'movies\nseries' | ${pkgs.fzf}/bin/fzf)
  fi

  ${pkgs.transmission}/bin/transmission-remote yellow.r \
    -w /var/download/finished/sorted/"$CATEGORY" \
    -a "$LINK"
''
