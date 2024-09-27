{ pkgs, ... }:
{
  programs.firefox.nativeMessagingHosts.tridactyl = true;
  environment.variables.BROWSER = "${pkgs.firefox-devedition}/bin/firefox-devedition";
  environment.systemPackages = [
    pkgs.firefox-devedition
  ];
}
