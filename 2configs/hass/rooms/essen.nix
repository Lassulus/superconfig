{ lib, ... }:
with import ../lib.nix { inherit lib; };

{
  services.home-assistant.config = lib.mkMerge [
    (detect_movement "essen" sensors.movement.essen lights.essen 70)
    (lightswitch "essen" switches.dimmer.essen lights.essen)
  ];
}
