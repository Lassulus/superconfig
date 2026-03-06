{ self, inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages.muchsync = inputs.wrappers.lib.wrapPackage {
        pkgs = pkgs;
        package = pkgs.muchsync;
        runtimeInputs = [ pkgs.notmuch ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.iputils ];
        env = {
          NOTMUCH_CONFIG = self.packages.${pkgs.system}.notmuch.passthru.configuration.configFile.path;
        };
        wrapper =
          { exePath, envString, ... }:
          ''
            ${envString}
            # Create Maildir structure if it doesn't exist
            mkdir -p "$HOME/Maildir"/{cur,new,tmp}

            MUCHSYNC_HOST="neoprism.lassul.us"
            MUCHSYNC_SSH="ssh -p 45621"

            # Check if we should do auto-sync
            # Auto-sync if no args or only verbose/config flags
            auto_sync=false
            if [ $# -eq 0 ]; then
              auto_sync=true
            else
              # Check if all args are sync-compatible flags
              all_sync_flags=true
              for arg in "$@"; do
                case "$arg" in
                  -v|-vv|-vvv|--verbose)
                    set -x  # Enable shell debugging for verbose mode
                    ;;  # Verbose flags
                  --config|--config=*) ;;     # Config flags
                  -*) all_sync_flags=false; break ;;  # Unknown flag, don't auto-sync
                  *) all_sync_flags=false; break ;;   # Non-flag argument, don't auto-sync
                esac
              done
              if [ "$all_sync_flags" = true ]; then
                auto_sync=true
              fi
            fi

            if [ "$auto_sync" = true ]; then
              exec ${exePath} -s "$MUCHSYNC_SSH" "$@" lass@"$MUCHSYNC_HOST"
            else
              # Pass through arguments to muchsync
              exec ${exePath} "$@"
            fi
          '';
      };
    };
}
