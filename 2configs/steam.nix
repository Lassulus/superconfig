{ pkgs, lib, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    package = pkgs.steam.override {
      extraPkgs = (
        pkgs: with pkgs; [
          gamemode
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXScrnSaver
          libpng
          libpulseaudio
          libvorbis
          stdenv.cc.cc.lib
          libkrb5
          keyutils
          # additional packages...
          # e.g. some games require python3
        ]
      );
      # extraLibraries = pkgs: [ pkgs.gperftools ];
      # - Automatically enable gamemode whenever Steam is running
      # -- NOTE: Assumes that a working system install of gamemode already exists!
      extraProfile =
        let
          gmLib = "${lib.getLib (pkgs.gamemode)}/lib";
        in
        ''
          export LD_LIBRARY_PATH="${gmLib}:$LD_LIBRARY_PATH"
        '';
    };
  };

  environment.systemPackages = with pkgs; [
    mangohud
  ];

  programs.gamemode.enable = true;
}
