{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.xonsh
    pkgs.xonsh2
  ];
}
