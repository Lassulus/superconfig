{ config, ... }:
{
  services.eternal-terminal = {
    enable = true;
  };
  networking.firewall.allowedTCPPorts = [ config.services.eternal-terminal.port ];
}
