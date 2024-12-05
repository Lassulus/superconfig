{ pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;

    packages = with pkgs; [
      xorg.fontschumachermisc
      inconsolata
      noto-fonts
      nerd-fonts.iosevka
      nerd-fonts.iosevka-term
    ];
  };
}
