{
  hardware.graphics.enable32Bit = true;
  services.pulseaudio.support32Bit = true;

  # Give user access to hidraw devices (needed for gamepad support in Wine/Proton)
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="input"
  '';
}
