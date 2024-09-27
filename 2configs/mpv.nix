{ pkgs, lib, ... }:

let
  dl_subs = pkgs.writers.writeDashBin "dl_subs" ''
    set -efu
    filename=$1
    cd "$(dirname "$filename")"
    filename=$(basename "$filename")
    ${pkgs.subdl}/bin/subdl --download=best-rating --existing=overwrite --output='/tmp/{m}.{M}.sub' "$filename" 1>&2
    echo "/tmp/$filename.sub"
  '';

  autosub = pkgs.writeText "autosub.lua" ''
    utils = require 'mp.utils'

    -- Log function: log to both terminal and mpv OSD (On-Screen Display)
    function log(string, secs)
        secs = secs or 2     -- secs defaults to 2 when the secs parameter is absent
        mp.msg.warn(string)          -- This logs to the terminal
        mp.osd_message(string, secs) -- This logs to mpv screen
    end

    function download()
        log('Searching subtitles ...', 10)
        path = mp.get_property('path')
        result = utils.subprocess({ args = {"${dl_subs}/bin/dl_subs", path} })
        if result.error == nil then
            filename = string.gsub(result.stdout, "\n", "")
            log(filename)
            mp.commandv('sub_add', filename)
            log('Subtitles ready!')
        else
            log('Subtitles failed downloading')
        end
    end

    mp.add_key_binding('S', "download_subs", download)
  '';

  mpvInput = pkgs.writeText "mpv.input" ''
    : script-binding console/enable
    x add audio-delay -0.050
    X add audio-delay 0.050
  '';

  mpvConfig = pkgs.writeText "mpv.conf" ''
    osd-font-size=20
  '';

  mpv = pkgs.symlinkJoin {
    name = "mpv";
    paths = [
      (pkgs.writeDashBin "mpv" ''
        set -efu
        Y_RES=1081
        # we need to disable sponsorblock local database because of
        # https://github.com/po5/mpv_sponsorblock/issues/31
        exec ${pkgs.mpv.override {
          scripts = with pkgs.mpvScripts; [
            sponsorblock
            quality-menu
            vr-reversal
          ];
        }}/bin/mpv \
         --no-config \
         --input-conf=${mpvInput} \
         --include=${mpvConfig} \
         --script=${autosub} \
         --ytdl-format="best[height<$Y_RES]" \
         --script-opts=ytdl_hook-ytdl_path=${pkgs.yt-dlp}/bin/yt-dlp \
         --script-opts-append=sponsorblock-local_database=no \
         --audio-channels=2 \
         "$@"
      '')
      pkgs.mpv
    ];
  };

in {
  environment.systemPackages = [
    mpv
    dl_subs
  ];
}
