{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lass.screenlock;

  out = {
    options.lass.screenlock = api;
    config = lib.mkIf cfg.enable imp;
  };

  api = {
    enable = lib.mkEnableOption "screenlock";
    command = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writers.writeDash "screenlock" ''
        ${pkgs.xlockmore}/bin/xlock -mode life1d -size 1
        sleep 3
      '';
    };
  };

  imp = {
    systemd.services.screenlock = {
      before = [ "sleep.target" ];
      requiredBy = [ "sleep.target" ];
      environment = {
        DISPLAY = ":${toString config.services.xserver.display}";
      };
      serviceConfig = {
        SyslogIdentifier = "screenlock";
        ExecStart = cfg.command;
        Type = "simple";
        User = "lass";
      };
    };
  };

in
out
