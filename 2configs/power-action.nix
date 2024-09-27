{ config, pkgs, ... }:

let
  suspend = pkgs.writers.writeDash "suspend" ''
    ${pkgs.systemd}/bin/systemctl suspend
  '';

  speak =
    text:
    pkgs.writers.writeDash "speak" ''
      ${pkgs.espeak}/bin/espeak -v +whisper -s 110 "${text}"
    '';

in
{
  krebs.power-action = {
    enable = true;
    plans.low-battery = {
      upperLimit = 10;
      lowerLimit = 15;
      charging = false;
      action = pkgs.writers.writeDash "warn-low-battery" ''
        ${speak "power level low"}
      '';
    };
    plans.suspend = {
      upperLimit = 10;
      lowerLimit = 0;
      charging = false;
      action = pkgs.writers.writeDash "suspend-wrapper" ''
        /run/wrappers/bin/sudo ${suspend}
      '';
    };
    user = "lass";
  };

  users.users.power-action = {
    isNormalUser = true;
    extraGroups = [
      "audio"
    ];
  };

  security.sudo.extraConfig = ''
    ${config.krebs.power-action.user} ALL= (root) NOPASSWD: ${suspend}
  '';
}
