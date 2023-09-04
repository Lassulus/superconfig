{ pkgs, ... }:

pkgs.writeScriptBin "pop" ''
  #! ${pkgs.bash}/bin/bash

  file=$1

  head -1 $file
  sed -i 1d $file
''
