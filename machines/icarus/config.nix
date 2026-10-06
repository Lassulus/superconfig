{ pkgs, ... }:

{
  imports = [
    ../../configs
    ../../configs/mouse.nix
    ../../configs/retiolum.nix
    ../../configs/desktops/xmonad
    ../../configs/pipewire.nix
    ../../configs/network-manager.nix
    ../../configs/red-host.nix
    ../../configs/snapclient.nix
    ../../configs/consul.nix
    ../../configs/autoupdate.nix
    ../../configs/sigexec/executor.nix
    ../../configs/rad.nix
  ];

  # services.xrdp = {
  #   enable = true;
  #   defaultWindowManager = "xmonad";
  # };
  # krebs.iptables.tables.filter.INPUT.rules = [
  #   { predicate = "-p tcp --dport 3389"; target = "ACCEPT"; } # xrdp
  # ];

  environment.systemPackages = [ pkgs.chromium ];

  # users.users.lass.openssh.authorizedKeys = [ config.krebs.users.mic92.pubkey ];
  system.stateVersion = "22.05";
}
