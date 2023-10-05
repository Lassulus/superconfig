{ pkgs, lib, ... }:

pkgs.writeDashBin "nm-dmenu" ''
  export PATH=$PATH:${lib.makeBinPath [
    pkgs.dmenu
    pkgs.networkmanagerapplet
    pkgs.procps
  ]}
  exec ${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu "$@"
''
