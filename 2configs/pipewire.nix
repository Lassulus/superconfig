{ pkgs, ... }:
{
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  environment.systemPackages = with pkgs; [
    alsa-utils
    pulseaudio
    ponymix
    bluetuith
  ];

  users.users.mainUser.extraGroups = [
    "bluetooth"
    "pipewire"
  ];

  services.pipewire = {
    enable = true;
    systemWide = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
}
