{ config, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
  ];

  krebs.build.host = config.krebs.hosts.lasspi;

  networking = {
    networkmanager = {
      enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    vim
    rxvt-unicode-unwrapped.terminfo
  ];
  services.openssh.enable = true;

  system.stateVersion = "22.05";
}
