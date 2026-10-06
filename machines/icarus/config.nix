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
  # networking.firewall.allowedTCPPorts = [ 3389 ]; # xrdp

  environment.systemPackages = [ pkgs.chromium ];

  # users.users.lass.openssh.authorizedKeys = [ self.inputs.kartei.users.mic92.pubkey ];
  system.stateVersion = "22.05";
}
