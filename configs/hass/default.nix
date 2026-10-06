{ config, pkgs, ... }:
{
  imports = [
    ./zigbee.nix
  ];

  networking.firewall.interfaces = {
    et0.allowedTCPPorts = [
      1883 # mosquitto
      8123 # hass
      1337 # zigbee2mqtt frontend
    ];
    docker0.allowedTCPPorts = [ 1883 ]; # mosquitto
    retiolum.allowedTCPPorts = [
      8123 # hass
      1337 # zigbee2mqtt frontend
    ];
    wiregrill.allowedTCPPorts = [ 8123 ]; # hass
    zttzibeakb.allowedTCPPorts = [ 8123 ]; # hass
  };

  systemd.services.hass-update = {
    startAt = "daily";
    script = ''
      ${pkgs.podman}/bin/podman pull ${config.virtualisation.oci-containers.containers.homeassistant.image}
      systemctl restart podman-homeassistant.service
      ${pkgs.podman}/bin/podman system prune -a --volumes -f
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

  services.ollama = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = [ pkgs.mosquitto ];
}
