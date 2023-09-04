{ config, lib, pkgs, ... }:
{
  services.atuin = {
    enable = true;
    host = "0.0.0.0";
    maxHistoryLength = 1000000;
    openFirewall = true;
  };

}
