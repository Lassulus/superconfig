{ config, ... }:

{
  imports = [
    ../../2configs/retiolum.nix
    ../../2configs/monitoring/prometheus.nix
    ../../2configs/monitoring/telegraf.nix
    ../../2configs/consul.nix
  ];

  krebs.build.host = config.krebs.hosts.dishfire;
}
