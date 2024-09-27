{ pkgs }:
let

  review = pkgs.writers.writeBash "review-mail" ''
    mail="$1"
    ${pkgs.exim}/bin/exim -Mvc "$mail" | grep -E 'Subject:|To:'
    ${pkgs.exim}/bin/exim -Mvl "$mail"
    while :; do
    read -p 'delete?' key
      case "$key" in
        v*)
          ${pkgs.exim}/bin/exim -Mvc "$mail"
        ;;
        d*)
          ${pkgs.exim}/bin/exim -Mrm "$mail"
          break
        ;;
        r*)
          ${pkgs.exim}/bin/exim -Mt "$mail"
          break
        ;;
        n*)
          break
        ;;
      esac
    done
    echo '-------------------'
    echo '-------------------'
    echo '-------------------'
    echo '-------------------'
    echo '-------------------'
  '';

in
pkgs.writers.writeBashBin "review-mail" ''
  for mail in $(${pkgs.exim}/bin/exim -bp \
  | ${pkgs.gnugrep}/bin/grep frozen \
  | ${pkgs.gawk}/bin/awk '{print $3}'); do
    ${review} "$mail"
  done
''
