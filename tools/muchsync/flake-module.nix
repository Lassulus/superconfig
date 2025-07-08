{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages.muchsync = self.libWithPkgs.${system}.makeWrapper pkgs.muchsync {
        runtimeInputs = [ pkgs.notmuch ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.iputils ];
        env = {
          NOTMUCH_CONFIG =
            pkgs.writeText "notmuch-config"
              self.packages.${pkgs.system}.mutt.passthru.notmuchConfig;
        };
        wrapper =
          { exePath, envString, ... }:
          ''
            ${envString}
            # Create Maildir structure if it doesn't exist
            mkdir -p "$HOME/Maildir"/{cur,new,tmp}

            # Check if a host is reachable
            check_host() {
              local host=$1
              ping -W2 -c1 "$host" >/dev/null 2>&1
            }

            # Smart host selection - try spora, nether, retiolum, then tor
            find_green_host() {
              if check_host green.s; then
                echo "green.s"
              elif check_host green.n; then
                echo "green.n"
              elif check_host green.r; then
                echo "green.r"
              else
                echo "tor"
              fi
            }

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
                  -v|-vv|-vvv|--verbose) ;;  # Verbose flags
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
              host=$(find_green_host)
              echo "Syncing with $host..." >&2

              if [ "$host" = "tor" ]; then
                # Build dependencies lazily
                echo "Building tornade..." >&2
                tornade_path=$(nix build --no-link --print-out-paths "${self}#tornade")
                clan_path=$(nix build --no-link --print-out-paths "${self}#clan-cli")

                # Get tor hostname using clan CLI
                tor_hostname=$(CLAN_DIR="${self}" "$clan_path/bin/clan" vars get green tor-ssh/tor-hostname)

                # Use muchsync with custom ssh command via tornade
                exec ${exePath} "$@" -s "$tornade_path/bin/tornade ssh" lass@"$tor_hostname"
              else
                exec ${exePath} "$@" lass@"$host"
              fi
            else
              # Pass through arguments to muchsync
              exec ${exePath} "$@"
            fi
          '';
      };
    };
}
