{
  pkgs,
  config,
  self,
  ...
}:
let
  # Patch noctalia-shell to use workspace name instead of number for sway
  # Quickshell's activate() sends "workspace number <num>" which fails for named workspaces (num=-1)
  noctalia-shell-patched = pkgs.noctalia-shell.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
          substituteInPlace $out/share/noctalia-shell/Services/Compositor/SwayService.qml \
            --replace-fail 'workspace.handle.activate();' \
              'Quickshell.execDetached([msgCommand, "workspace", workspace.name]);' \
            --replace-fail 'property bool initialized: false' \
              'property bool globalWorkspaces: true
      property bool initialized: false'
    '';
  });
in
{
  systemd.user.services.noctalia-shell = {
    description = "Noctalia Shell - Wayland desktop shell";
    documentation = [ "https://docs.noctalia.dev" ];
    partOf = [ "sway-session.target" ];
    wantedBy = [ "sway-session.target" ];
    after = [ "sway-session.target" ];
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.procps
      pkgs.util-linux
      pkgs.sway
      pkgs.brightnessctl
      pkgs.pulseaudio
      pkgs.networkmanager
      pkgs.wl-clipboard
    ];
    serviceConfig = {
      ExecStart = "${noctalia-shell-patched}/bin/noctalia-shell";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [
    noctalia-shell-patched
    # ryzenadj and power-profile for power profile control
    pkgs.ryzenadj
    self.packages.${pkgs.system}.power-profile
  ];

  # Idle inhibit service - toggled by bar button
  systemd.user.services.sway-idle-inhibit = {
    description = "Inhibit idle/sleep";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep --who=noctalia --why='User requested' --mode=block sleep infinity";
    };
  };

  # Allow user to run ryzenadj without password (for power profile switching)
  security.sudo.extraRules = [
    {
      users = [ config.users.users.mainUser.name ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Make RAPL energy counters readable for power monitoring
  services.udev.extraRules = ''
    SUBSYSTEM=="powercap", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chmod a+r /sys/class/powercap/%k/energy_uj"
  '';

  # Configure noctalia darkModeChange hook to trigger switch-theme
  # This makes noctalia's dark mode button also switch the system theme
  system.activationScripts.noctalia-hooks.text =
    let
      jq = "${pkgs.jq}/bin/jq";
      settingsFile = "/home/${config.users.users.mainUser.name}/.config/noctalia/settings.json";
    in
    ''
      if [ -f "${settingsFile}" ]; then
        ${jq} '
          .hooks.enabled = true |
          .hooks.darkModeChange = "if [ \"$1\" = \"true\" ]; then switch-theme dark; else switch-theme light; fi"
        ' "${settingsFile}" > "${settingsFile}.tmp" && \
          mv "${settingsFile}.tmp" "${settingsFile}" && \
          chown ${config.users.users.mainUser.name}:users "${settingsFile}" || true
      fi
    '';
}
