{ lib, ... }:
with import ../lib.nix { inherit lib; };

{
  services.home-assistant.config = lib.mkMerge [
    (detect_movement "nass" sensors.movement.nass lights.nass 100)
    (lightswitch "nass" switches.dimmer.nass lights.nass)
  ];
}

