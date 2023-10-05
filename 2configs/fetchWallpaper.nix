{ config, pkgs, ... }:

let

in {
  krebs.fetchWallpaper = {
    enable = true;
    url = "http://wallpaper.r/realwallpaper-krebs-stars-berlin.png";
  };
}

