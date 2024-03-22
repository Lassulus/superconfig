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
  ];

  services.pipewire = {
    enable = true;
    systemWide = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # workaround from https://github.com/NixOS/nixpkgs/pull/297806#issuecomment-2014059176
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/59-systemwide-bluetooth.conf" ''
      wireplumber.profiles = {
        main = {
          monitor.bluez.seat-monitoring = disabled
        }
      }
    '')
  ];
}
