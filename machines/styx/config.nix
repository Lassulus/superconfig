{ config, lib, pkgs, ... }:

{
  imports = [
    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/desktops/xmonad
    ../../2configs/pipewire.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/nfs-dl.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/gg23.nix
    ../../2configs/hass
    ../../2configs/green-host.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/home-media.nix
    ../../2configs/syncthing.nix
    ../../2configs/ppp/umts-stick.nix
    ../../2configs/snapserver.nix
    ../../2configs/snapclient.nix
    ../../2configs/consul.nix
    # ../../2configs/news-host.nix
  ];

  krebs.build.host = config.krebs.hosts.styx;

  krebs.power-action.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    wol
    (writeDashBin "wake-alien" ''
      ${wol}/bin/wol -h 10.42.0.255 10:65:30:68:83:a3
    '')
    (writers.writeDashBin "iptv" ''
      set -efu
      /run/current-system/sw/bin/mpv \
        --audio-display=no --audio-channels=stereo \
        --audio-samplerate=48000 --audio-format=s16 \
        --ao-pcm-file=/run/snapserver/snapfifo --ao=pcm \
        --audio-delay=-1 \
        --playlist=https://iptv-org.github.io/iptv/index.nsfw.m3u \
        --idle=yes \
        --input-ipc-server=/tmp/mpv.ipc \
        "$@"
    '')
  ];

  # http://10.42.0.1:8081/smokeping.fcgi
  networking.firewall.allowedTCPPorts = [ 80 ];
  services.smokeping = {
    enable = true;
    host = null;
    targetConfig = ''
      probe = FPing
      menu = top
      title = top

      + Local
      menu = Local
      title = Local Network
      ++ LocalMachine
      menu = Local Machine
      title = This host
      host = localhost

      + Internet
      menu = internet
      title = internet

      ++ CloudflareDNS
      menu = Cloudflare DNS
      title = Cloudflare DNS server
      host = 1.1.1.1

      ++ GoogleDNS
      menu = Google DNS
      title = Google DNS server
      host = 8.8.8.8

      + retiolum
      menu = retiolum
      title = retiolum

      ++ gum
      menu = gum.r
      title = gum.r
      host = gum.r

      ++ ni
      menu = ni.r
      title = ni.r
      host = ni.r

      ++ prism
      menu = prism.r
      title = prism.r
      host = prism.r
    '';
  };

  # for usb internet
  hardware.usbWwan.enable = true;
}

