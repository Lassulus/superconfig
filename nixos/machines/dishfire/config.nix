{ config, lib, pkgs, ... }:

{
  imports = [
    <stockholm/lass>
    <stockholm/lass/2configs/retiolum.nix>
    <stockholm/lass/2configs/monitoring/prometheus.nix>
    <stockholm/lass/2configs/monitoring/telegraf.nix>
    <stockholm/lass/2configs/consul.nix>
  ];

  krebs.build.host = config.krebs.hosts.dishfire;
}
