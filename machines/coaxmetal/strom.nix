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

  # Bluetooth pairing helper for Xbox Wireless Controllers. Run `strom-pair`
  # once per controller (as root / on the console, e.g.
  # `ssh root@coaxmetal.r strom-pair`): put the pad in pairing mode (hold the
  # Xbox button to power on, then hold the small round sync button on the top
  # edge until the light flashes rapidly) and the script blocks until it pairs
  # that one pad, then exits. A pad currently paired to another device is
  # re-paired here (its stale bond is cleared); a pad already connected and
  # working is left alone. Run once per controller. Bonded+trusted pads
  # reconnect on their own on every later boot. Pass a MAC to pair just one.
  strom-pair = pkgs.writeShellApplication {
    name = "strom-pair";
    runtimeInputs = [ pkgs.bluez ];
    text = ''
      # Find one Xbox pad that is here right now (advertising in pairing mode)
      # and not already connected; echo its MAC (empty if none). We key off what
      # actually shows up in THIS scan, not the bonded-device list: a pad that
      # was since re-paired to another host still lingers as "bonded" here but
      # only appears in a scan when it is genuinely present and pairable.
      find_target() {
        local sl m
        local -a bonded present
        sl=$(mktemp)
        bluetoothctl --timeout 12 scan on > "$sl" 2>&1 || true
        mapfile -t bonded < <(bluetoothctl devices 2>/dev/null | grep -i xbox | awk '{print $2}')
        # MACs of xbox pads that showed up in this scan (present + advertising).
        mapfile -t present < <(
          {
            # freshly discovered pads announce their name
            grep -i xbox "$sl" | grep -oiE '([0-9a-f]{2}:){5}[0-9a-f]{2}'
            # known/bonded pads emit nameless RSSI lines; match their MAC in-scan
            for m in "''${bonded[@]:-}"; do
              [ -n "$m" ] && grep -qiF "$m" "$sl" && printf '%s\n' "$m"
            done
          } | sort -uf
        )
        rm -f "$sl"
        for m in "''${present[@]:-}"; do
          [ -n "$m" ] || continue
          bluetoothctl info "$m" 2>/dev/null | grep -q "Connected: yes" && continue
          printf '%s\n' "$m"
          return 0
        done
        return 0
      }

      # Pair one pad. Xbox controllers use JustWorks pairing, which needs a
      # NoInputNoOutput agent held in the SAME bluetoothctl session as `pair`
      # (plus disable_ertm, set system-wide below). Remove any existing bond
      # first: a pad re-paired to another host still shows bonded here but never
      # reconnects, and bluez refuses a fresh pair while that stale bond exists.
      # `connect` succeeds even when pairing fails, so success is judged by
      # "Bonded: yes", not by connect.
      pair_one() {
        local mac="$1"
        bluetoothctl remove "$mac" >/dev/null 2>&1 || true
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

      # Single-pad mode: (re)pair exactly the given MAC and exit.
      if [ -n "''${1:-}" ]; then
        if pair_one "$1"; then
          echo ">> paired, trusted, connected: $1"
          exit 0
        fi
        echo "!! could not pair $1." >&2
        exit 1
      fi

      # Default: wait for a pad that is present and in pairing mode, (re)pair it,
      # then exit. Run once per controller. A pad that was paired to another
      # device in the meantime is re-paired here (its stale bond is cleared)
      # rather than skipped; a pad already connected and working is left alone.
      echo ">> put a controller in pairing mode: hold the Xbox button to power"
      echo "   on, then hold the small round sync button on the top edge until"
      echo "   the light flashes rapidly. Waiting... (Ctrl-C to abort)"
      while true; do
        echo ">> scanning..."
        mac=$(find_target)
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
