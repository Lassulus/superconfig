{ self, pkgs, ... }:
{
  environment.systemPackages = [
    self.packages.${pkgs.system}.notmuch
    self.packages.${pkgs.system}.mutt
    pkgs.muchsync
  ];
}
