{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.termite
  ];

  krebs.per-user.lass.packages = let
    termitecfg = pkgs.writeTextFile {
      name = "termite-config";
      destination = "/etc/xdg/termite/config";
      text = ''
        [colors]
        foreground = #d0d7d0
        background = #000000
      '';
    };
  in [
    termitecfg
  ];
}
