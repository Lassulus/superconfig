{ config, pkgs, ... }:
{
  systemd.services.rebuild-on-boot = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      NIX_REMOTE = "daemon";
      HOME = "/var/empty";
    };
    serviceConfig = {
      ExecStart = pkgs.writeScript "rebuild" ''
        #!${pkgs.bash}/bin/bash
        (/run/current-system/sw/bin/nixos-rebuild -I /var/src switch) &
      '';
      ExecStop = "${pkgs.coreutils}/bin/sleep 10";
    };
  };
}
