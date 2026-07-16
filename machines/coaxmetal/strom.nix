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
    # Relaunch whenever the couch launcher exits (gamepad B / Esc) so the kiosk
    # never drops to a blank tty. Keeping the loop as cage's child means the
    # compositor stays up across relaunches.
    while true; do
      ${config.nix.package}/bin/nix run --refresh github:kraftwerk-gaming/strom#scripts.launcher
      sleep 2
    done
  '';

  # Bluetooth pairing helper for Xbox Wireless Controllers. Run `strom-pair`
  # once per controller (as root / on the console, e.g.
  # `ssh root@coaxmetal.r strom-pair`): put the pad in pairing mode (hold the
  # Xbox button to power on, then hold the small round sync button on the top
  # edge until the light flashes rapidly) and the script blocks until it pairs
  # that one fresh pad, then exits. Already-bonded pads are skipped, so just run
  # it again for the next controller. Bonded+trusted pads reconnect on their own
  # on every later boot. Pass a MAC (`strom-pair AA:BB:...`) to pair just one.
  strom-pair = pkgs.writeShellApplication {
    name = "strom-pair";
    runtimeInputs = [ pkgs.bluez ];
    text = ''
      # Find one not-yet-bonded Xbox pad, echoing its MAC (empty if none). A
      # foreground timed scan is reliable; a backgrounded `scan on` exits at once
      # without a tty and never actually scans.
      find_unpaired() {
        local m
        bluetoothctl --timeout 12 scan on >/dev/null 2>&1 || true
        mapfile -t cand < <(bluetoothctl devices 2>/dev/null | grep -i xbox | awk '{print $2}')
        for m in "''${cand[@]:-}"; do
          [ -n "$m" ] || continue
          bluetoothctl info "$m" 2>/dev/null | grep -q "Bonded: yes" && continue
          printf '%s\n' "$m"
          return 0
        done
        return 0
      }

      # Pair one pad. Xbox controllers use JustWorks pairing, which needs a
      # NoInputNoOutput agent held in the SAME bluetoothctl session as `pair`
      # (plus disable_ertm, set system-wide below). `connect` succeeds even when
      # pairing fails, so success is judged by "Bonded: yes", not by connect.
      pair_one() {
        local mac="$1"
        {
          echo "power on"
          echo "agent NoInputNoOutput"
          echo "default-agent"
          echo "scan on"
          sleep 14
          echo "pair $mac"
          sleep 12
          echo "trust $mac"
          echo "connect $mac"
          sleep 4
          echo "quit"
        } | bluetoothctl >/dev/null 2>&1 || true
        # Bonding can finalize a moment after the session exits; poll a few
        # seconds before deciding it failed.
        for _ in 1 2 3 4 5; do
          bluetoothctl info "$mac" 2>/dev/null | grep -q "Bonded: yes" && return 0
          sleep 1
        done
        return 1
      }

      bluetoothctl power on >/dev/null 2>&1 || true

      # Single-pad mode: pair exactly the given MAC and exit.
      if [ -n "''${1:-}" ]; then
        if pair_one "$1"; then
          echo ">> paired, trusted, connected: $1"
          exit 0
        fi
        echo "!! could not pair $1." >&2
        exit 1
      fi

      # Default: wait for one fresh (unbonded) pad, pair it, then exit. Run once
      # per controller; already-bonded pads are ignored so each run grabs the
      # next one.
      echo ">> put a controller in pairing mode: hold the Xbox button to power"
      echo "   on, then hold the small round sync button on the top edge until"
      echo "   the light flashes rapidly. Waiting... (Ctrl-C to abort)"
      while true; do
        echo ">> scanning..."
        mac=$(find_unpaired)
        # Show which Xbox pads are visible and whether they are already bonded,
        # so it's obvious if the pad is being detected at all.
        bluetoothctl devices 2>/dev/null | grep -i xbox | while read -r _ m _; do
          if bluetoothctl info "$m" 2>/dev/null | grep -q "Bonded: yes"; then
            echo "   seen $m (already bonded, skipping)"
          else
            echo "   seen $m (pairable)"
          fi
        done
        if [ -n "$mac" ]; then
          printf '>> pairing %s ... ' "$mac"
          if pair_one "$mac"; then
            echo "OK"
            echo ">> paired, trusted, connected: $mac"
            exit 0
          fi
          echo "failed, retrying (keep it in pairing mode)"
        fi
        sleep 1
      done
    '';
  };
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
  environment.systemPackages = [
    pkgs.brightnessctl
    strom-pair
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
  # 2configs/pipewire.nix. Pair each pad once with `strom-pair` (see above).
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
  };
}
