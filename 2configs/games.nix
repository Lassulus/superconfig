{ config, pkgs, ... }:

let
  mainUser = config.users.extraUsers.mainUser;

in
{
  users.extraUsers = {
    games = {
      name = "games";
      description = "user playing games";
      home = "/home/games";
      extraGroups = [
        "audio"
        "video"
        "input"
        "loot"
        "pipewire"
      ];
      createHome = true;
      useDefaultShell = true;
      packages = with pkgs; [
        # minecraft
        # ftb
        # steam-run
        # scummvm
        # dolphinEmu
        # doom1
        # doom2
        # protontricks
        # vdoom1
        # vdoom2
        # vdoomserver
        retroarchBare
      ];
      isNormalUser = true;
    };
  };

  hardware.graphics.enable32Bit = true;
  services.pulseaudio.support32Bit = true;

  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(games) NOPASSWD: ALL
  '';

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport 10666";
      target = "ACCEPT";
    }
    {
      predicate = "-p udp --dport 10666";
      target = "ACCEPT";
    }
  ];
}
