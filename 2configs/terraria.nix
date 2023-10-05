{ config, lib, pkgs, ... }:
{
  services.terraria = {
    enable = true;
    openFirewall = true;
  };

  users.groups.terraria = {};
  users.users.terraria.group = "terraria";

  # mobile
  # nixpkgs.config.packageOverrides = pkgs: {
  #   terraria-server = pkgs.terraria-server.overrideAttrs (_: {
  #     src = pkgs.fetchurl {
  #       url = "https://terraria.org/api/download/mobile-dedicated-server/Terraria-Mobile-Server-1.4.3.2.zip";
  #       sha256 = "sha256-Gl/pXylT6NPUY0SwhlPXtsRSkpVtJc5mWdxSYC4T30w=";
  #     };
  #   });
  # };
}

