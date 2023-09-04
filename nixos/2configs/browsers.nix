{ config, lib, pkgs, ... }:
{
  programs.firefox.nativeMessagingHosts.tridactyl = true;
  environment.variables.BROWSER = "${pkgs.firefox}/bin/firefox";
  environment.systemPackages = [
    pkgs.firefox-devedition
  ];
}
