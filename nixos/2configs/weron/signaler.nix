{ config, lib, pkgs, ... }:
{
  systemd.services.weron-signaler = {
    wantedBy = [ "multi-user.target" ];
    environment = {
    };
    serviceConfig = {
      ExecStart = ''${pkgs.weron}/bin/weron signaler --verbose=7 --laddr ":23420"'';
    };
  };

  networking.firewall.allowedTCPPorts = [ 23420 ];
}
