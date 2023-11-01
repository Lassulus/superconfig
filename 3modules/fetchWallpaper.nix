{ config, lib, pkgs, ... }:

let
  cfg = config.lass.fetchWallpaper;

  fetchWallpaperScript = pkgs.writers.writeDash "fetchWallpaper" ''
    set -euf

    mkdir -p ${cfg.stateDir}
    chmod o+rx ${cfg.stateDir}
    cd ${cfg.stateDir}
    (curl -s -o wallpaper.tmp -z wallpaper.tmp ${lib.escapeShellArg cfg.url} && cp wallpaper.tmp wallpaper) || :
    feh --no-fehbg --bg-scale wallpaper
  '';

in {
  options.lass.fetchWallpaper = {
    enable = lib.mkEnableOption "fetch wallpaper";
    url = lib.mkOption {
      type = lib.types.str;
    };
    timerConfig = lib.mkOption {
      type = lib.types.unspecified;
      default = {
        OnCalendar = "*:00,10,20,30,40,50";
      };
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wallpaper";
    };
    display = lib.mkOption {
      type = lib.types.str;
      default = ":${toString config.services.xserver.display}";
    };
    unitConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Extra unit configuration for fetchWallpaper to define conditions and assertions for the unit";
      example = lib.literalExample ''
        # do not start when running on umts
        { ConditionPathExists = "!/var/run/ppp0.pid"; }
      '';
      default = {};
    };
  };

  config = {
    systemd.timers.fetchWallpaper = {
      description = "fetch wallpaper timer";
      wantedBy = [ "timers.target" ];

      timerConfig = cfg.timerConfig;
    };
    systemd.services.fetchWallpaper = {
      description = "fetch wallpaper";
      after = [ "network.target" ];

      path = with pkgs; [
        curl
        feh
      ];

      environment = {
        URL = cfg.url;
        DISPLAY = cfg.display;
      };
      restartIfChanged = true;

      serviceConfig = {
        Type = "simple";
        ExecStart = fetchWallpaperScript;
        User = "fetchWallpaper";
        StateDirectory = true;
        StateDirectoryMode = "0755";
      };

      unitConfig = cfg.unitConfig;
    };
  };
}
