{ lib, ... }:
{
  hardware.trackpoint = {
    enable = true;
    sensitivity = 220;
    speed = 0;
    emulateWheel = true;
  };

  services.libinput.enable = lib.mkForce false;
  services.xserver.synaptics = {
    enable = true;
    horizEdgeScroll = false;
    horizontalScroll = false;
    vertEdgeScroll = false;
    maxSpeed = "0.1";
    minSpeed = "0.01";
    tapButtons = false;
  };
}
