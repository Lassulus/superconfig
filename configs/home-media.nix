{ self, pkgs, ... }:
{
  imports = [
  ];
  users.users.media = {
    isNormalUser = true;
    uid = self.inputs.stockholm.lib.genid_uint31 "media";
    extraGroups = [
      "video"
      "audio"
      "pipewire"
    ];
    packages = [
      (pkgs.writers.writeDashBin "mpv" ''
        if test -e "$1"; then
          mpv-ipc-cli loadfile "$(realpath "$1")"
        else
          mpv-ipc-cli loadfile "$1"
        fi
      '')
    ];
  };

  users.users.mainUser.packages = [
    (pkgs.writers.writeDashBin "mpv" ''
      if test -e "$1"; then
        mpv-ipc-cli loadfile "$(realpath "$1")"
      else
        mpv-ipc-cli loadfile "$1"
      fi
    '')
  ];

  services.xserver.displayManager.autoLogin = {
    enable = true;
    user = "media";
  };

  hardware.pulseaudio.configFile = pkgs.writeText "pulse.pa" ''
    .include ${pkgs.pulseaudioFull}/etc/pulse/default.pa
    load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;10.42.0.0/24 auth-anonymous=1
  '';

  environment.systemPackages = [
    (pkgs.writers.writeDashBin "mpv-ipc-cli" ''
      set -efux
      ${pkgs.jq}/bin/jq -nc '{ "command": $ARGS.positional }' --args "$@" | ${pkgs.socat}/bin/socat - /tmp/mpv.ipc
    '')
    (pkgs.writers.writeDashBin "ipc-mpv" ''
      /run/current-system/sw/bin/mpv \
        --audio-display=no --audio-channels=stereo \
        --audio-samplerate=48000 --audio-format=s16 \
        --ao-pcm-file=/run/snapserver/snapfifo --ao=pcm \
        --audio-delay=-1 \
        "$@"
    '')
    pkgs.mpvc
    (pkgs.writers.writeDashBin "iptv" ''
      curl -Ssf 'https://iptv-org.github.io/iptv/index.nsfw.m3u' |
        sed 's/.*,//' |
        sed -z 's/\nhttp/,http/g' |
        fzf --bind='enter:execute(echo {} | cut -d ',' -f 2 | xargs -0 mpv-ipc-cli loadfile)'
    '')
  ];

  environment.variables.SOCKET = "/tmp/mpv.ipc";
  systemd.services.mpvd = {
    wantedBy = [ "multi-user.target" ];
    environment.DISPLAY = ":0";
    serviceConfig = {
      User = "media";
      RemainAfterExit = true;
      Nice = "-10";
      ExecStart = ''
        ${pkgs.tmux}/bin/tmux -2 new-session -d -s mpvd -- /run/current-system/sw/bin/ipc-mpv \
                --audio-display=no --audio-channels=stereo \
                --audio-samplerate=48000 --audio-format=s16 \
                --ao-pcm-file=/run/snapserver/snapfifo --ao=pcm \
                --audio-delay=-1 \
                --network-timeout=3 \
                --untimed --cache-pause=no \
                --idle=yes --force-window=yes \
                --loop-playlist=inf \
                --input-ipc-server=/tmp/mpv.ipc
      '';
      ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t mpvd";
      ExecStartPre = [
        "+${pkgs.writers.writeDash "remove_socket" ''
          set -efux
          rm -f /tmp/mpv.ipc
        ''}"
      ];
      ExecStartPost = [
        "+${pkgs.writers.writeDash "fix_permissions" ''
          set -efux
          until test -e /tmp/mpv.ipc; do
            sleep 1
          done
          # sleep 2
          chmod 666 /tmp/mpv.ipc || :
        ''}"
      ];
    };
  };
}
