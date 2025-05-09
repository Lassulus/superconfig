{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages = [
      pkgs.tridactyl-native
    ];
    package = pkgs.firefox-devedition;
  };
  environment.variables.BROWSER = "${pkgs.firefox-devedition}/bin/firefox-devedition";
}
