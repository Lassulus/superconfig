{ self, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/network-manager.nix
    ../../2configs/pipewire.nix
    ../../2configs/yubikey.nix
    ../../2configs/tpm2.nix
  ];
  system.stateVersion = "25.05";

  krebs.build.host = self.inputs.stockholm.kartei.hosts.xerxes;

  programs.sway.enable = true;
  programs.firefox.enable = true;
  environment.systemPackages = [
    pkgs.bitwarden-desktop
    pkgs.rbw
    pkgs.retroarch-free
    pkgs.pavucontrol
    pkgs.claude-code
  ];
}
