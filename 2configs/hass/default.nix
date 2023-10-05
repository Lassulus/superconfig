{ config, lib, pkgs, ... }:
{
  imports = [
    ./pyscript
    ./zigbee.nix
    ./rooms/bett.nix
    ./rooms/essen.nix
    ./rooms/nass.nix
  ];

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i int0 -p tcp --dport 1883"; target = "ACCEPT"; } # mosquitto
    { predicate = "-i docker0 -p tcp --dport 1883"; target = "ACCEPT"; } # mosquitto
    { predicate = "-i int0 -p tcp --dport 8123"; target = "ACCEPT"; } # hass
    { predicate = "-i int0 -p tcp --dport 1337"; target = "ACCEPT"; } # zigbee2mqtt frontend
    { predicate = "-i retiolum -p tcp --dport 8123"; target = "ACCEPT"; } # hass
    { predicate = "-i retiolum -p tcp --dport 1337"; target = "ACCEPT"; } # zigbee2mqtt frontend
    { predicate = "-i wiregrill -p tcp --dport 8123"; target = "ACCEPT"; } # hass
  ];

  # TODO add auto update
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
    listeners = [{
      acl = [ ];
      users.gg23 = { acl = [ "readwrite #" ]; password = "gg23-mqtt"; };
    }];
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
