{ config, ... }:

{
  services.urxvtd.enable = true;

  krebs.xresources.resources.urxvt = ''
    URxvt.saveLines: 10000
    URxvt.scrollBar: false
    URxvt.urgentOnBell: true
    URxvt.perl-ext: default,matcher

    URxvt.url-launcher: /run/current-system/sw/bin/browser-select
    URxvt.matcher.pattern.1:  \\bwww\\.[\\w-]+\\.[\\w./?&@#-]*[\\w/-]

    URxvt.keysym.M-Escape: perl:keyboard-select:activate
    URxvt.keysym.M-s: perl:keyboard-select:search
    URxvt.keysym.M-u: matcher:select
    URxvt.keysym.M-i: matcher:list

    URxvt.keysym.M-F1: command:\033]710;${config.lass.fonts.regular}\007\033]711;${config.lass.fonts.bold}\007
    URxvt.keysym.M-F2: command:\033]710;xft:Monospace:size=12\007\033]711;xft:Monospace:size=15:bold\007
    URxvt.keysym.M-F3: command:\033]710;xft:Monospace:size=18\007\033]711;xft:Monospace:size=20:bold\007
    URxvt.keysym.M-F4: command:\033]710;xft:Monospace:size=25\007\033]711;xft:Monospace:size=25:bold\007
    URxvt.keysym.M-F5: command:\033]710;xft:Monospace:size=30\007\033]711;xft:Monospace:size=30:bold\007

    URxvt.intensityStyles: false

    URxvt*background: #000000
    URxvt*foreground: #ffffff

    !change unreadable blue
    URxvt*color4: #268bd2

    URxvt*color0: #232342
  '';
}
