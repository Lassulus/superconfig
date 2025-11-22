{ pkgs, ... }:
{
  services.snapserver = {
    enable = true;
    # openFirewall = true;
    settings.stream = {
      source = [
        "process://${pkgs.writers.writeDash "radio" ''
          exec ${pkgs.mpv}/bin/mpv http://radio.lassul.us/radio.ogg \
            --no-terminal \
            --audio-display=no \
            --audio-channels=stereo \
            --audio-samplerate=48000 \
            --audio-format=s16 \
            --ao=pcm \
            --ao-pcm-file=/dev/stdout
        ''}?name=radio"
        "pipe:///run/snapserver/snapfifo?name=styx"
      ];
    };
    http.enable = true;
  };

  networking.firewall.interfaces.int0.allowedTCPPorts = [
    1704
    1705
    1780
  ];
  networking.firewall.interfaces.retiolum.allowedTCPPorts = [ 1780 ];
}
