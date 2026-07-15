{
  pkgs,
  lib,
  config,
  self,
  ...
}:
let
  inherit (config.users.users.mainUser) name home group;
  wallpaperDir = "${home}/wallpaper";

  wallpaper = self.packages.${pkgs.system}.wallpaper;
in
{
  # Seed ~/wallpaper with the starter live wallpaper (pixel-art road/trees/
  # sunset from moewalls, transcoded to 1080p30 without audio). `C` copies it
  # once when missing, so the user can freely add or delete wallpapers
  # afterwards without it reappearing.
  systemd.tmpfiles.rules = [
    "d ${wallpaperDir} 0755 ${name} ${group} -"
    "C ${wallpaperDir}/road-trees-sunset-sky-pixel.mp4 0644 ${name} ${group} - ${./wallpapers/road-trees-sunset-sky-pixel.mp4}"
  ];

  # Live wallpaper: mpvpaper renders a random file from ~/wallpaper on the
  # background layer. noctalia's own wallpaper is disabled (see the noctalia
  # wrapper) so this shows through.
  systemd.user.services.wallpaper = {
    description = "Live desktop wallpaper (mpvpaper)";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    after = [ "sway-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = lib.getExe wallpaper;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Rotate to a fresh random wallpaper once a day by restarting the service.
  systemd.user.services.wallpaper-rotate = {
    description = "Rotate the live desktop wallpaper";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} --user restart wallpaper.service";
    };
  };

  systemd.user.timers.wallpaper-rotate = {
    description = "Daily live wallpaper rotation";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
