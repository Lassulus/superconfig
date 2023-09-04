{ config, lib, pkgs, ... }:
{
  systemd.services.weron = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      WERON_RADDR = "ws://lassul.us:23420/";
    };
    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "weron" ''
        ${pkgs.weron}/bin/weron vpn ip \
          --community krebs \
          --password aidsballs \
          --key aidsballs \
          --ips 10.249.1.0/24 \
          --verbose 7 \
          --dev weron
      '';
    };
  };
}
