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

            # Check if arguments look like flags or a hostname
            has_hostname=false
            for arg in "$@"; do
              case "$arg" in
                -*) ;;  # This is a flag
                *) has_hostname=true; break ;;  # Found a non-flag argument
              esac
            done

            # If only flags provided (or no args), do a sync with green host
            if [ "$has_hostname" = "false" ]; then
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
