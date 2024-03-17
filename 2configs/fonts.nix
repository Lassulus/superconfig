{ pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;

    packages = with pkgs; [
      xorg.fontschumachermisc
      inconsolata
      noto-fonts
      (iosevka-bin.override { variant = "SS15"; })
    ];
  };
}
