{ pkgs, self, ... }:
{
  environment.systemPackages = [
    self.packages.${pkgs.system}.firefox
    self.packages.${pkgs.system}.workspace-browser
  ];
  environment.variables.BROWSER = "/run/current-system/sw/bin/firefox";
}
