{ config, pkgs, self, ... }:
{
  # v4l2loopback with two devices: raw camera and ASCII output
  boot = {
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    extraModprobeConfig = ''
      options v4l2loopback devices=2 video_nr=0,1 exclusive_caps=0,1 card_label="Phone Camera","ASCII Webcam"
    '';
  };

  environment.systemPackages = [
    pkgs.android-tools
    self.packages.${pkgs.system}.android-webcam
  ];
}
