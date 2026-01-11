{ self, pkgs, ... }:
{
  # Blacklist DVB-T driver so rtl-sdr can use the device
  boot.blacklistedKernelModules = [ "dvb_usb_rtl28xxu" ];

  # Use rtl-sdr-blog for V4 support (also works with V3 and other RTL-SDRs)
  # This installs udev rules for all known RTL-SDR devices
  services.udev.packages = [ pkgs.rtl-sdr-blog ];

  # Ensure plugdev group exists and mainUser is a member (used by rtl-sdr udev rules)
  users.groups.plugdev = {};
  users.users.mainUser.extraGroups = [ "plugdev" ];

  # SDR and TETRA tools
  environment.systemPackages = [
    pkgs.rtl-sdr-blog  # V4 compatible drivers and tools
    pkgs.gqrx          # SDR receiver with spectrum analyzer
    pkgs.sox           # Audio processing for recordings
    self.packages.${pkgs.system}.tetra-kit
    self.packages.${pkgs.system}.tetra-receiver
  ];
}
