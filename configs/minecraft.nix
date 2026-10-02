{ ... }:
{
  services.minecraft-server = {
    enable = true;
    eula = true;
  };
  networking.firewall.allowedTCPPorts = [ 25565 ];
  networking.firewall.allowedUDPPorts = [ 25565 ];
}
