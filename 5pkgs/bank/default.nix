{ writeDashBin, coreutils, pass, hledger, diffutils }:

writeDashBin "bank" ''
  tmp=$(mktemp)
  ${pass}/bin/pass show hledger > $tmp
  ${hledger}/bin/hledger --file=$tmp "$@"
  ${pass}/bin/pass show hledger | if ${diffutils}/bin/diff $tmp -; then
    exit 0
  else
    ${coreutils}/bin/cat $tmp | ${pass}/bin/pass insert -m hledger
  fi
  ${coreutils}/bin/rm $tmp
''

