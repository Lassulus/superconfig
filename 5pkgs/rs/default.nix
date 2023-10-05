{ pkgs, ... }:

#TODO: get tab-completion working again
pkgs.writeBashBin "rs" ''
  rsync -vaP --append-verify "$@"
''
