{ pkgs, self, ... }:
{
  environment.systemPackages = [
    self.packages.${pkgs.system}.firefox
  ];
  environment.variables.BROWSER = "${self.packages.${pkgs.system}.firefox}/bin/firefox";
}
