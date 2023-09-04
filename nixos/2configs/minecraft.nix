{ pkgs, ... }: let

  unstable = import <nixpkgs-unstable> { config.allowUnfree = true; };

in {
  services.minecraft-server = {
    enable = true;
    eula = true;
    package = unstable.minecraft-server;
  };
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];
}
