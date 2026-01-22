{ pkgs, self, ... }:
{
  environment.systemPackages = [
    self.packages.${pkgs.system}.firefox
  ];
  environment.variables.BROWSER = "/run/current-system/sw/bin/firefox";
}
