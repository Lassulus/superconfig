{ config, pkgs, ... }:
{
  imports = [
    ./zigbee.nix
  ];

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i int0 -p tcp --dport 1883";
      target = "ACCEPT";
    } # mosquitto
    {
      predicate = "-i docker0 -p tcp --dport 1883";
      target = "ACCEPT";
    } # mosquitto
    {
      predicate = "-i int0 -p tcp --dport 8123";
      target = "ACCEPT";
    } # hass
    {
      predicate = "-i int0 -p tcp --dport 1337";
      target = "ACCEPT";
    } # zigbee2mqtt frontend
    {
      predicate = "-i retiolum -p tcp --dport 8123";
      target = "ACCEPT";
    } # hass
    {
      predicate = "-i retiolum -p tcp --dport 1337";
      target = "ACCEPT";
    } # zigbee2mqtt frontend
    {
      predicate = "-i wiregrill -p tcp --dport 8123";
      target = "ACCEPT";
    } # hass
    {
      predicate = "-i zttzibeakb -p tcp --dport 8123";
      target = "ACCEPT";
    } # hass
  ];

  systemd.services.hass-update = {
    startAt = "daily";
    script = ''
      ${pkgs.podman}/bin/podman pull ${config.virtualisation.oci-containers.containers.homeassistant.image}
      ${pkgs.podman}/bin/podman stop homeassistant
      ${pkgs.podman}/bin/podman start homeassistant
      ${pkgs.podman}/bin/podman system prune
    '';
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "Europe/Berlin";
      image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ ];
        users.gg23 = {
          acl = [ "readwrite #" ];
          password = "gg23-mqtt";
        };
      }
    ];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
