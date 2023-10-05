{ config, pkgs, ... }:

let
  mainUser = config.users.extraUsers.mainUser;
  vdoom = pkgs.writers.writeDash "vdoom" ''
    ${pkgs.zandronum}/bin/zandronum \
      -fov 120 \
      "$@"
  '';
  doom = pkgs.writers.writeDash "doom" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}
    ${vdoom} \
      -file $DOOM_DIR/lib/brutalv21.pk3 \
      "$@"
  '';
  doom1 = pkgs.writers.writeDashBin "doom1" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}
    ${doom} -iwad $DOOM_DIR/wads/stock/doom.wad "$@"
  '';
  doom2 = pkgs.writers.writeDashBin "doom2" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}
    ${doom} -iwad $DOOM_DIR/wads/stock/doom2.wad "$@"
  '';
  vdoom1 = pkgs.writers.writeDashBin "vdoom1" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}
    ${vdoom} -iwad $DOOM_DIR/wads/stock/doom.wad "$@"
  '';
  vdoom2 = pkgs.writers.writeDashBin "vdoom2" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}
    ${vdoom} -iwad $DOOM_DIR/wads/stock/doom2.wad "$@"
  '';

  doomservercfg = pkgs.writeText "doomserver.cfg" ''
    skill 7
    #survival true
    #sv_maxlives 4
    #sv_norespawn true
    #sv_weapondrop true
    no_jump true
    #sv_noweaponspawn true
    sv_sharekeys true
    sv_survivalcountdowntime 1
    sv_noteamselect true
    sv_updatemaster false
    #sv_coop_loseinventory true
    #cl_startasspectator false
    #lms_spectatorview false
  '';

  vdoomserver = pkgs.writers.writeDashBin "vdoomserver" ''
    DOOM_DIR=''${DOOM_DIR:-~/doom/}

    ${pkgs.zandronum}/bin/zandronum-server \
    +exec ${doomservercfg} \
    "$@"
  '';

in {
  users.extraUsers = {
    games = {
      name = "games";
      description = "user playing games";
      home = "/home/games";
      extraGroups = [ "audio" "video" "input" "loot" "pipewire" ];
      createHome = true;
      useDefaultShell = true;
      packages = with pkgs; [
        # minecraft
        # ftb
        # steam-run
        # scummvm
        # dolphinEmu
        doom1
        doom2
        # protontricks
        vdoom1
        # vdoom2
        # vdoomserver
        retroarchBare
      ];
      isNormalUser = true;
    };
  };

  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(games) NOPASSWD: ALL
  '';

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 10666"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 10666"; target = "ACCEPT"; }
  ];
}
