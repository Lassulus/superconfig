{ config, pkgs, lib, ... }:
let
  cfg = config.services.ipfs-pin-watcher;

  pinWatcherScript = pkgs.writers.writeBash "ipfs-pin-watcher" ''
    set -efu

    IPFS="${pkgs.kubo}/bin/ipfs"
    INOTIFYWAIT="${pkgs.inotify-tools}/bin/inotifywait"
    CID_MAP="${cfg.cidMapFile}"

    # ensure cid map file exists
    touch "$CID_MAP"

    log() {
      echo "[$(date -Iseconds)] $*"
    }

    add_file() {
      local path="$1"
      # skip if not a regular file
      [ -f "$path" ] || return 0
      # skip partial/temp files
      case "$(basename "$path")" in
        .* | *.part | *.tmp) return 0 ;;
      esac

      log "Adding $path"
      cid=$($IPFS add --nocopy --pin --quieter "$path" 2>&1) || {
        log "Failed to add $path: $cid"
        return 0
      }
      log "Pinned $path -> $cid"
      # store mapping (remove old entry for this path first)
      ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      echo "$cid $path" >> "$CID_MAP"
    }

    remove_file() {
      local path="$1"
      # look up CID from our map
      cid=$(${pkgs.gawk}/bin/awk -v p="$path" '$0 ~ p {print $1; exit}' "$CID_MAP")
      if [ -n "$cid" ]; then
        log "Unpinning $cid ($path)"
        $IPFS pin rm "$cid" 2>/dev/null || true
        # remove from map
        ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      else
        log "No CID found for removed file: $path"
      fi
    }

    # initial sync: add all existing files
    log "Starting initial sync of watched directories..."
    for dir in ${lib.escapeShellArgs cfg.watchDirs}; do
      if [ -d "$dir" ]; then
        ${pkgs.findutils}/bin/find "$dir" -type f | while read -r f; do
          # skip if already in map
          if ! ${pkgs.gnugrep}/bin/grep -q " $f$" "$CID_MAP" 2>/dev/null; then
            add_file "$f"
          fi
        done
      fi
    done
    log "Initial sync complete"

    # clean up stale entries (files in map but no longer on disk)
    log "Cleaning stale entries..."
    while IFS=' ' read -r cid path; do
      if [ ! -f "$path" ]; then
        log "Stale entry: $path (CID: $cid)"
        $IPFS pin rm "$cid" 2>/dev/null || true
        ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      fi
    done < "$CID_MAP"
    log "Cleanup complete"

    # watch for changes
    log "Watching directories: ${lib.concatStringsSep ", " cfg.watchDirs}"
    $INOTIFYWAIT -m -r \
      -e close_write \
      -e moved_to \
      -e moved_from \
      -e delete \
      ${lib.escapeShellArgs cfg.watchDirs} |
    while read -r dir event file; do
      path="''${dir}''${file}"
      case "$event" in
        CLOSE_WRITE*|MOVED_TO*)
          add_file "$path"
          ;;
        DELETE*|MOVED_FROM*)
          remove_file "$path"
          ;;
      esac
    done
  '';
in
{
  options.services.ipfs-pin-watcher = {
    enable = lib.mkEnableOption "IPFS auto-pin watcher";
    watchDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Directories to watch for new files to auto-pin in IPFS";
      example = [ "/var/download/movies" "/var/download/shows" "/var/download/games" ];
    };
    cidMapFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ipfs/cid-map.txt";
      description = "File to store CID-to-path mappings for unpinning";
    };
  };

  config = lib.mkIf cfg.enable {
    services.kubo = {
      enable = true;
      settings = {
        Experimental.FilestoreEnabled = true;
        # listen on all interfaces so it's reachable via retiolum
        Addresses = {
          API = [
            "/ip4/0.0.0.0/tcp/5001"
            "/ip6/::/tcp/5001"
          ];
          Gateway = [
            "/ip4/0.0.0.0/tcp/8080"
            "/ip6/::/tcp/8080"
          ];
        };
        # set a reasonable storage max for garbage collection
        Datastore.StorageMax = "100GB";
      };
    };

    # bump inotify limits for large directories
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;

    systemd.services.ipfs-pin-watcher = {
      description = "Auto-pin files to IPFS using inotify";
      after = [ "kubo.service" ];
      requires = [ "kubo.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = pinWatcherScript;
        Restart = "always";
        RestartSec = "10s";
        User = config.services.kubo.user;
        Group = config.services.kubo.group;
        # ipfs needs access to download dirs
        SupplementaryGroups = [ "download" ];
      };
    };

    networking.firewall.allowedTCPPorts = [
      4001  # IPFS swarm
      5001  # IPFS API
      8080  # IPFS gateway
    ];
    networking.firewall.allowedUDPPorts = [
      4001  # IPFS swarm (QUIC)
    ];
  };
}
