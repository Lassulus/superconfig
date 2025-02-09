{ pkgs, lib, ... }:
let
  qtile = (pkgs.python3.pkgs.qtile.override {
    pulsectl-asyncio = pkgs.python3.pkgs.pulsectl-asyncio.overrideAttrs (oldAttrs: {
      postPatch = ''
        substituteInPlace setup.cfg --replace "pulsectl >=23.5.0,<=24.11.0" "pulsectl >=23.5.0"
      '';
    });
    extraPackages = [
      pkgs.python3.pkgs.dbus-fast
    ];
  }).overrideAttrs (oldAttrs: {
    pname = "qtile-0.29.0";
    version = "0.29.0";
    src = pkgs.fetchFromGitHub {
      owner = "qtile";
      repo = "qtile";
      tag = "v0.29.0";
      hash = "sha256-EqrvBXigMjevPERTcz3EXSRaZP2xSEsOxjuiJ/5QOz0=";
    };
  });
  # qtile-extras = pkgs.python3.pkgs.qtile-extras.override {
  #   qtile = qtile;
  # };
in
{
  imports = [
    ../lib/wayland.nix
  ];

  environment.sessionVariables.XDG_CURRENT_DESKTOP = "qtile";
  services.greetd.enable = true;

  # For greetd, we need a shell script into path, which lets us start qtile.service (after importing the environment of the login shell).
  services.greetd.settings.default_session.command = "${pkgs.greetd.tuigreet}/bin/tuigreet --remember --cmd ${pkgs.writeScript "startqtile" ''
    #! ${pkgs.bash}/bin/bash

    # first import environment variables from the login manager
    export XDG_DATA_DIRS=/run/current-system/sw/share/gsettings-schemas:$XDG_DATA_DIRS
    systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY
    systemctl --user import-environment XDG_DATA_DIRS PATH
    # then start the service
    exec systemctl --user --wait start qtile.service
  ''}";

  systemd.user.targets.qtile-session = {
    description = "Qtile compositor session";
    documentation = [ "man:systemd.special(7)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  environment.systemPackages = [
    qtile
    pkgs.copyq
  ];

  systemd.user.services.qtile =
    let
      pyEnv = pkgs.python3.withPackages (_p: [
        qtile
        # qtile-extras
        pkgs.python3.pkgs.iwlib
      ]);
    in
    {
      description = "Qtile - Wayland window manager";
      documentation = [ "man:qtile(5)" ];
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
      # We explicitly unset PATH here, as we want it to be set by
      # systemctl --user import-environment in startqtile
      environment.PATH = lib.mkForce null;
      environment.PYTHONPATH = lib.mkForce null;
      environment.PYTHONTRACEMALLOC = "1";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pyEnv}/bin/qtile start -b wayland -c /etc/qtile.py";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

  environment.etc."qtile.py".source = ./qtile.py;
}
