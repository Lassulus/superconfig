{ config, lib, pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;

    fonts = with pkgs; [
      xorg.fontschumachermisc
      inconsolata
      noto-fonts
      (iosevka-bin.override { variant = "ss15"; })
    ];
  };
}
