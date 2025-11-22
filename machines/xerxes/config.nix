{ self, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/network-manager.nix
  ];
  system.stateVersion = "25.05";

  krebs.build.host = self.inputs.stockholm.kartei.hosts.xerxes;

  programs.sway.enable = true;
  environment.systemPackages = [
    pkgs.foot
  ];
}
