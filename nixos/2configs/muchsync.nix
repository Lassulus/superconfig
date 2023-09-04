{ config, pkgs, ... }:

{
  systemd.services.muchsync = let
    hosts = [
      "coaxmetal.r"
      "mors.r"
      "green.r"
    ];
  in {
    description = "sync mails";
    environment = {
      NOTMUCH_CONFIG = config.environment.variables.NOTMUCH_CONFIG;
    };
    after = [ "network.target" ];

    restartIfChanged = false;

    path = [
      pkgs.notmuch
      pkgs.openssh
    ];

    startAt = "*:*"; # run every minute
    serviceConfig = {
      User = "lass";
      Type = "oneshot";
      ExecStart = pkgs.writeDash "sync-mails" ''
        set -euf

        /run/current-system/sw/bin/nm-tag-init 2>/dev/null
        ${concatMapStringsSep "\n" (host: ''
          echo syncing ${host}:
          ${pkgs.muchsync}/bin/muchsync -s 'ssh -CTaxq -o ConnectTimeout=4' --nonew lass@${host} || :
        '') hosts}
      '';
    };
  };
}
