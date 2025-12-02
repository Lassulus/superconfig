{ pkgs, lib, ... }:

pkgs.writers.writeDashBin "nm-dmenu" ''
  export PATH=$PATH:${
    lib.makeBinPath [
      (pkgs.writers.writeDashBin "dmenu" ''
        exec ${lib.getExe pkgs.rofi} -dmenu "$@"
      '')
      pkgs.networkmanagerapplet
      pkgs.procps
    ]
  }
  exec ${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu "$@"
''
