{
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../2configs
    ../../2configs/desktops/sway/default.nix
    ../../2configs/pipewire.nix
    ../../2configs/network-manager.nix
    self.wrapperModules.workspace-manager
  ];

  krebs.build.host.name = "atlas";
  system.stateVersion = "25.05";

  lass.workspace-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  # Autostart straight into sway: greetd logs the main user in on boot with no
  # prompt and execs sway (a login shell so the wrapped sway + session env from
  # programs.sway are on PATH). default_session with a real user means every
  # (re)start goes directly into the session — there is no greeter.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${lib.getExe pkgs.bash} --login -c sway";
      user = config.users.users.mainUser.name;
    };
  };

  # Stateless box: no password/credential is baked into the image, so a screen
  # lock could never be unlocked (swaylock PAM has nothing to accept). Disable
  # the desktop's idle auto-lock (swayidle: lock after 120s, suspend-then-
  # hibernate after 300s) and the lock service itself. The $mod+l / $mod+F11
  # lock keybinds then start an empty lock.target and harmlessly do nothing.
  systemd.user.services.swayidle.enable = lib.mkForce false;
  systemd.user.services.swaylock.enable = lib.mkForce false;

  # Noctalia pops a one-time "Privacy Update" telemetry wizard whenever its
  # cache (~/.cache/noctalia/shell-state.json) has an empty
  # changelogState.lastSeenVersion (UpdateService.shouldShowTelemetryWizard,
  # gated only on that cache — not on any setting). This box is stateless, so
  # the cache is wiped every boot and the wizard returned on every start.
  # Seed the cache before noctalia launches with the current version, so it
  # treats the changelog/telemetry notice as already seen (and, since
  # lastSeen == currentVersion, the changelog stays closed too).
  systemd.user.services.noctalia-seed-state = {
    description = "Seed noctalia changelog cache (suppress telemetry wizard on stateless boots)";
    partOf = [ "sway-session.target" ];
    wantedBy = [ "noctalia-shell.service" ];
    before = [ "noctalia-shell.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "noctalia-seed-state" ''
        set -eu
        dir="''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia"
        f="$dir/shell-state.json"
        ver="v${pkgs.noctalia-shell.version}"
        mkdir -p "$dir"
        if [ -s "$f" ]; then
          ${pkgs.jq}/bin/jq --arg v "$ver" \
            '.changelogState.lastSeenVersion = (if (.changelogState.lastSeenVersion // "") == "" then $v else .changelogState.lastSeenVersion end)' \
            "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        else
          ${pkgs.jq}/bin/jq -n --arg v "$ver" '{changelogState:{lastSeenVersion:$v}}' > "$f"
        fi
      '';
    };
  };
}
