{ pkgs, ... }:
{
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;

    packages = with pkgs; [
      xorg.fontschumachermisc
      inconsolata
      noto-fonts
      (nerdfonts.override {
        fonts = [
          "Iosevka"
          "IosevkaTerm"
          "IosevkaTermSlab"
        ];
      })
    ];
  };
}
