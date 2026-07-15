{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Always pull the newest launcher straight from the public flake instead of
  # pinning it as an input, so the game grid tracks upstream on every (re)launch.
  # The launcher itself only shells out to `nix run <flake>#<slug>` per game, so
  # its closure stays tiny; games bring their own nested gamescope/proton.
  strom-session = pkgs.writeShellScript "strom-session" ''
    set -u
    # Relaunch whenever the couch launcher exits (gamepad B / Esc) so the kiosk
    # never drops to a blank tty. Keeping the loop as cage's child means the
    # compositor stays up across relaunches.
    while true; do
      ${config.nix.package}/bin/nix run --refresh github:kraftwerk-gaming/strom#scripts.launcher
      sleep 2
    done
  '';
in
{
  # Dedicated, unprivileged kiosk user. Gamepad input comes through evdev
  # (input group), audio through the system-wide pipewire socket (pipewire
  # group), and the games need video/audio like any local player.
  users.users.strom = {
    isNormalUser = true;
    extraGroups = [
      "video"
      "audio"
      "input"
      "pipewire"
    ];
  };

  # Kiosk autostart. After the initrd ZFS/LUKS unlock hands off to the running
  # system, graphical.target pulls up cage on tty1, which logs the strom user
  # in with no prompt and runs the fullscreen launcher as its sole Wayland
  # client. This is the canonical NixOS single-app kiosk path.
  services.cage = {
    enable = true;
    user = "strom";
    program = strom-session;
  };

  # Recover the compositor itself if it ever crashes (the session loop above
  # already handles a launcher exit without tearing cage down).
  systemd.services.cage-tty1.serviceConfig = {
    Restart = lib.mkDefault "always";
    RestartSec = 2;
  };

  # The panel comes up at ~1% backlight, unreadable for a couch setup. Ship
  # brightnessctl + its udev rules (chgrp backlight to the video group, g+w) so
  # any video-group user (strom, lass) can adjust it without root, e.g.
  # `brightnessctl set 100%` / `brightnessctl set 50%`.
  environment.systemPackages = [ pkgs.brightnessctl ];
  services.udev.packages = [ pkgs.brightnessctl ];

  # Force the backlight to maximum on every boot. Ordered after
  # systemd-backlight, which would otherwise restore the last (dim) saved level.
  systemd.services.max-brightness = {
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-backlight@backlight:amdgpu_bl1.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.brightnessctl}/bin/brightnessctl set 100%";
    };
  };
}
