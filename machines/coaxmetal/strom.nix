{
  config,
  pkgs,
  ...
}:
let
  # Run the patched launcher from the on-disk strom checkout at
  # /home/strom/strom (it carries STROM_NO_GAMESCOPE support until that lands
  # upstream). With the kiosk itself being a gamescope session (below), games
  # are launched as <slug>.no-gamescope so they render directly in the session
  # compositor instead of nesting a per-game gamescope.
  strom-session = pkgs.writeShellScript "strom-session" ''
    set -u
    # xpadneo owns the Xbox pad's hidraw node, so force SDL (pygame launcher and
    # the games) to read the pad through evdev instead of its HIDAPI backend -
    # same fix as 2configs/steam.nix, without it SDL finds no controller.
    export SDL_JOYSTICK_HIDAPI_XBOX=0
    # SDL's udev-monitor hotplug does not deliver in this kiosk session, so a pad
    # powered on after the launcher starts is never seen. Force SDL to poll
    # /dev/input instead, which reliably picks up pads as they connect/disconnect.
    export SDL_JOYSTICK_DISABLE_UDEV=1
    # Under cage the launcher window never reports input focus, and SDL suppresses
    # joystick (not keyboard) events while unfocused - so keyboard works but the
    # pad does not. Allow joystick events regardless of focus.
    export SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1
    # The kiosk compositor is already gamescope on DRM (see services.greetd
    # below), so tell the launcher to run games directly in it rather than
    # nesting a per-game gamescope (which double-nests and, on this GPU, storms
    # the Vulkan swapchain and crashes games like Baba Is You).
    export STROM_NO_GAMESCOPE=1
    # strom-run (the per-game supervisor) needs a delegated cgroup v2 so it can
    # mkdir a child cgroup and cgroup.kill the game tree atomically. The greetd
    # PAM session drops us into a root-owned logind session scope
    # (user-1011.slice/session-cN.scope) that is NOT delegated, so strom-run dies
    # with "could not create cgroup (Permission denied)" and the game never
    # launches. Re-parent into a delegated transient scope under the user manager
    # (user@UID.service, which logind DOES delegate). Wait for the user bus first:
    # on boot the PAM session opens slightly before the user manager's bus socket.
    rd="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for _ in $(seq 1 50); do
      [ -S "$rd/bus" ] && break
      sleep 0.2
    done
    # Relaunch whenever the couch launcher exits (gamepad B / Esc) so the kiosk
    # never drops to a blank screen. The loop runs inside the delegated scope so
    # every game inherits a writable cgroup; the gamescope compositor stays up
    # (it is the session's other child) across relaunches.
    #
    # setpriv --ambient-caps=-all: the login session may carry an ambient
    # capability (e.g. cap_wake_alarm) that every child inherits. bwrap refuses
    # to start when it sees capabilities in its permitted set without being
    # setuid ("Unexpected capabilities but not setuid, old file caps config?"),
    # which instant-crashes every sandboxed game. Drop the ambient set for the
    # whole launcher tree so bwrap (and thus each game) starts clean.
    exec ${pkgs.systemd}/bin/systemd-run --user --scope -p Delegate=yes \
      --quiet --collect -- \
      ${pkgs.util-linux}/bin/setpriv --ambient-caps=-all \
      ${pkgs.bash}/bin/bash -c 'while true; do
        ${config.nix.package}/bin/nix run /home/strom/strom#scripts.launcher
        sleep 2
      done'
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

  # Kiosk autostart: a gamescope session on DRM (via greetd autologin),
  # replacing cage. gamescope presents straight to the display, so there is no
  # nested Wayland swapchain for RADV to storm on this Vega iGPU. greetd gives
  # the strom user a real seat/VT (DRM master) and a delegated user manager,
  # which the launcher's systemd-run --user --scope relies on for game cgroups.
  services.greetd = {
    enable = true;
    settings =
      let
        session = {
          command = "${pkgs.gamescope}/bin/gamescope -- ${strom-session}";
          user = "strom";
        };
      in
      {
        # initial_session autologins on boot with no prompt; default_session
        # re-runs it (also autologin) if the gamescope session ever exits.
        initial_session = session;
        default_session = session;
      };
  };

  # The panel comes up at ~1% backlight, unreadable for a couch setup. Ship
  # brightnessctl + its udev rules (chgrp backlight to the video group, g+w) so
  # any video-group user (strom, lass) can adjust it without root, e.g.
  # `brightnessctl set 100%` / `brightnessctl set 50%`.
  environment.systemPackages = [
    pkgs.brightnessctl
  ];
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

  # Xbox Wireless Controllers (Bluetooth). xpadneo for correct rumble/axis
  # mapping; the two bluez tweaks + disable_ertm are what make Xbox pads
  # actually bond (without disable_ertm they fail with AuthenticationFailed).
  # Bluetooth itself (adapter + powerOnBoot) already comes from
  # 2configs/pipewire.nix. Pair pads with bluetuith (also from pipewire.nix).
  hardware.xpadneo.enable = true;
  # Xbox One/Series controllers pair over Bluetooth only with L2CAP ERTM off.
  boot.extraModprobeConfig = "options bluetooth disable_ertm=1";
  hardware.bluetooth.settings.General = {
    # JustWorksRepairing lets bluez accept fresh pairings without a manual
    # remove; Privacy = device pins a static host address so the controller's
    # bond key survives RPA rotation.
    JustWorksRepairing = "always";
    Privacy = "device";
    # Keep page scan always on so a bonded pad reconnects promptly when powered
    # back on (otherwise bonded pads bond but never re-link). Fine on a
    # mains-powered kiosk.
    FastConnectable = true;
    # In this busy-RF LAN environment the cache fills with hundreds of stray
    # BLE devices; evict non-bonded ones ~30s after they leave range so they
    # do not pile up and saturate the adapter.
    TemporaryTimeout = 30;
  };

  # Persistent JustWorks pairing agent. Xbox pads pair via JustWorks, and on
  # reconnect a pad whose bond went stale re-initiates pairing. bluez needs a
  # registered agent to auto-confirm that; bluetuith only provides one while you
  # are actively pairing in it, so an autonomous re-pair hits "No agent
  # available for request type 2" and the link drops. Keep a NoInputNoOutput
  # agent registered at all times so pairing/re-pairing just works.
  systemd.services.bt-agent = {
    wantedBy = [ "multi-user.target" ];
    after = [ "bluetooth.service" ];
    requires = [ "bluetooth.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
