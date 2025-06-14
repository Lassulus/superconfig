{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.muchsync = pkgs.symlinkJoin {
        name = "muchsync";
        paths = [
          (pkgs.writeShellApplication {
            name = "muchsync";
            runtimeInputs = [
              pkgs.muchsync
              pkgs.notmuch
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              pkgs.iputils
            ];
            text = ''
              export NOTMUCH_CONFIG=${pkgs.writeText "notmuch-config" self.packages.${pkgs.system}.mutt.passthru.notmuchConfig}
              
              set -efu

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

              # If no arguments provided, do a sync with green host
              if [ $# -eq 0 ]; then
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
                  exec muchsync -s "$tornade_path/bin/tornade ssh" lass@"$tor_hostname"
                else
                  exec muchsync lass@"$host"
                fi
              else
                # Pass through arguments to muchsync
                exec muchsync "$@"
              fi
            '';
          })
          pkgs.muchsync
        ];
      };
    };
}