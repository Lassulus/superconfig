{ config, lib, pkgs, ... }:

let
  hostname = config.krebs.build.host.name;
  inherit (lib)
    nameValuePair
  ;

in {
  krebs.realwallpaper.enable = true;

  system.activationScripts.wallpaper-chmod = ''
    ${pkgs.coreutils}/bin/chmod +rx /var/realwallpaper
  '';
  services.nginx.virtualHosts.wallpaper = {
    extraConfig = ''
      if ( $server_addr = "${config.krebs.build.host.nets.internet.ip4.addr}" ) {
        return 403;
      }
    '';
    serverAliases = [
      "wallpaper.r"
    ];
    locations."/".extraConfig = ''
      autoindex on;
      root /var/realwallpaper/;
    '';
    locations."/realwallpaper.png".extraConfig = ''
      root /var/realwallpaper/;
    '';
    locations."/realwallpaper-krebs.png".extraConfig = ''
      root /var/realwallpaper/;
    '';
    locations."/realwallpaper-krebs-stars.png".extraConfig = ''
      root /var/realwallpaper/;
    '';
    locations."/realwallpaper-krebs-stars-berlin.png".extraConfig = ''
      root /var/realwallpaper/;
    '';
    locations."/realwallpaper-video.mp4".extraConfig = ''
      root /var/realwallpaper/archive;
    '';
  };

  krebs.iptables = {
    tables = {
      filter.INPUT.rules = [
        { predicate = "-i retiolum -p tcp --dport 80"; target = "ACCEPT"; }
      ];
    };
  };
}
