{ pkgs, lib, ... }:

let
  dl_subs = pkgs.writers.writeDashBin "dl_subs" ''
    filename=$1
    ${pkgs.subdl}/bin/subdl --output='/tmp/{m}.{M}.sub' "$filename" 1>&2
    echo "/tmp/$(basename "$filename").sub"
  '';

  autosub = pkgs.writeText "autosub.lua" ''
    -- Requires Subliminal version 1.0 or newer
    -- Make sure to specify your system's Subliminal location below:
    local utils = require 'mp.utils'

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

    -- Control function: only download if necessary
    function control_download()
        duration = tonumber(mp.get_property('duration'))
        if duration < 900 then
            mp.msg.warn('Video is less than 15 minutes\n', '=> NOT downloading any subtitles')
            return
        end
        -- There does not seem to be any documentation for the 'sub' property,
        -- but it works on both internally encoded as well as external subtitle files!
        -- -> sub = '1' when subtitles are present
        -- -> sub = 'no' when subtitles are not present
        -- -> sub = 'auto' when called before the 'file-loaded' event is triggered
        sub = mp.get_property('sub')
        if sub == '1' then
            mp.msg.warn('Sub track is already present\n', '=> NOT downloading other subtitles')
            return
        end
        mp.msg.warn('No sub track was detected\n', '=> Proceeding to download subtitles:')
        download()
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
