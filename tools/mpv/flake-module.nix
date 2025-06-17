{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.mpv =
        let
          mpvInput = pkgs.writeText "mpv.input" ''
            : script-binding console/enable
            x add audio-delay -0.050
            X add audio-delay 0.050
          '';

          mpvConfig = pkgs.writeText "mpv.conf" ''
            osd-font-size=20
          '';

          # Lazy-loaded autosub script
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
                
                -- Build dl_subs lazily when needed
                log('Building subtitle downloader...', 5)
                result = utils.subprocess({ args = {"nix", "build", "--no-link", "--print-out-paths", "${self}#mpv-dl-subs"} })
                if result.error ~= nil then
                    log('Failed to build subtitle downloader')
                    return
                end
                
                dl_subs_path = string.gsub(result.stdout, "\n", "") .. "/bin/dl_subs"
                
                -- Download subtitles
                result = utils.subprocess({ args = {dl_subs_path, path} })
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

          mpvPackage = pkgs.mpv.override {
            scripts = with pkgs.mpvScripts; [
              sponsorblock
              quality-menu
              vr-reversal
              visualizer
            ];
          };

        in
        pkgs.writeShellApplication {
          name = "mpv";
          runtimeInputs = [
            mpvPackage
            pkgs.yt-dlp
          ];
          text = ''
            Y_RES=1081
            # we need to disable sponsorblock local database because of
            # https://github.com/po5/mpv_sponsorblock/issues/31
            exec mpv \
             --no-config \
             --input-conf=${mpvInput} \
             --include=${mpvConfig} \
             --script=${autosub} \
             --ytdl-format="best[height<$Y_RES]" \
             --script-opts=ytdl_hook-ytdl_path=${pkgs.yt-dlp}/bin/yt-dlp \
             --script-opts-append=sponsorblock-local_database=no \
             --audio-channels=2 \
             "$@"
          '';
        };

      # Separate package for subtitle downloader
      packages.mpv-dl-subs =
        pkgs.writers.writePython3Bin "dl_subs"
          {
            libraries = [ pkgs.python3Packages.subliminal ];
            flakeIgnore = [ "E501" ];
          }
          ''
            import babelfish
            import subliminal
            from pathlib import Path
            import sys
            import os

            video_path = Path(sys.argv[1])
            video = subliminal.scan_video(video_path)
            cache_path = Path(os.path.expanduser("~/.cache/subliminal")) / f"{video.title}.srt"
            if not cache_path.exists():
                cache_path.parent.mkdir(parents=True, exist_ok=True)
                language = babelfish.Language("eng")
                sub = subliminal.download_best_subtitles([video], {language})[video][0]
                cache_path.write_bytes(sub.content)
            print(cache_path)
          '';
    };
}
