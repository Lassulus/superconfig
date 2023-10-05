{ pkgs }:
pkgs.writers.writeDashBin "nix-index-update" ''
  set -efux
  filename="index-$(uname -m)-$(uname | tr A-Z a-z)"
  mkdir -p ~/.cache/nix-index && cd ~/.cache/nix-index
  # -N will only download a new version if there is an update.
  ${pkgs.wget}/bin/wget -q -N https://github.com/Mic92/nix-index-database/releases/latest/download/$filename
  ln -f $filename files
''
