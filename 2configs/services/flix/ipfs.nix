{
  config,
  pkgs,
  lib,
  ...
}:
let
  watchDirs = [
    "/var/lib/ipfs/download/movies"
    "/var/lib/ipfs/download/shows"
    "/var/lib/ipfs/download/games"
  ];

  cidMapFile = "/var/lib/ipfs/cid-map.txt";

  pinWatcherScript = pkgs.writers.writeBash "ipfs-pin-watcher" ''
    set -efu

    IPFS="${pkgs.kubo}/bin/ipfs"
    INOTIFYWAIT="${pkgs.inotify-tools}/bin/inotifywait"
    CID_MAP="${cidMapFile}"

    touch "$CID_MAP"

    log() {
      echo "[$(date -Iseconds)] $*"
    }

    add_file() {
      local path="$1"
      [ -f "$path" ] || return 0
      case "$(basename "$path")" in
        .* | *.part | *.tmp | *.synced.*) return 0 ;;
      esac

      log "Adding $path"
      cid=$($IPFS add --nocopy --pin --quieter "$path" 2>/dev/null) || {
        log "Failed to add $path"
        return 0
      }
      log "Pinned $path -> $cid"
      ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      echo "$cid $path" >> "$CID_MAP"
    }

    remove_file() {
      local path="$1"
      cid=$(${pkgs.gawk}/bin/awk -v p="$path" '$0 ~ p {print $1; exit}' "$CID_MAP")
      if [ -n "$cid" ]; then
        log "Unpinning $cid ($path)"
        $IPFS pin rm "$cid" 2>/dev/null || true
        ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      else
        log "No CID found for removed file: $path"
      fi
    }

    # initial sync
    log "Starting initial sync..."
    for dir in ${lib.escapeShellArgs watchDirs}; do
      if [ -d "$dir" ]; then
        ${pkgs.findutils}/bin/find "$dir" -type f | while read -r f; do
          if ! ${pkgs.gnugrep}/bin/grep -q " $f$" "$CID_MAP" 2>/dev/null; then
            add_file "$f"
          fi
        done
      fi
    done
    log "Initial sync complete"

    # clean stale entries
    log "Cleaning stale entries..."
    while IFS=' ' read -r cid path; do
      if [ ! -f "$path" ]; then
        log "Stale entry: $path (CID: $cid)"
        $IPFS pin rm "$cid" 2>/dev/null || true
        ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      fi
    done < "$CID_MAP"
    log "Cleanup complete"

    # add all files in a newly appeared directory
    scan_new_dir() {
      local dir="$1"
      log "Scanning new directory: $dir"
      ${pkgs.findutils}/bin/find "$dir" -type f | while read -r f; do
        add_file "$f"
      done
    }

    # watch for changes
    log "Watching directories: ${lib.concatStringsSep ", " watchDirs}"
    $INOTIFYWAIT -m -r --format $'%w\t%e\t%f' \
      -e close_write \
      -e moved_to \
      -e moved_from \
      -e delete \
      -e create \
      ${lib.escapeShellArgs watchDirs} |
    while IFS=$'\t' read -r dir event file; do
      path="''${dir}''${file}"
      case "$event" in
        CREATE,ISDIR*|MOVED_TO,ISDIR*)
          scan_new_dir "$path"
          ;;
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
  # symlink /var/download into IPFS root so --nocopy works
  systemd.tmpfiles.rules = [
    "L+ /var/lib/ipfs/download - - - - /var/download"
  ];

  services.kubo = {
    enable = true;
    settings = {
      Experimental.FilestoreEnabled = true;
      Addresses = {
        API = [
          "/ip4/127.0.0.1/tcp/5001"
          "/ip6/::1/tcp/5001"
        ];
        Gateway = [
          "/ip4/0.0.0.0/tcp/8089"
          "/ip6/::/tcp/8089"
        ];
      };
      Datastore.StorageMax = "100GB";
      # limit bandwidth: 5MB/s out, 5MB/s in
      Swarm.ConnMgr = {
        LowWater = 20;
        HighWater = 50;
        GracePeriod = "10s";
      };
      Swarm.Transports.Network.TCP = true;
      Swarm.Transports.Network.QUIC = false;
      Swarm.ResourceMgr = {
        Enabled = true;
        MaxMemory = "256MB";
      };
      # disable relay to reduce overhead
      Swarm.RelayClient.Enabled = false;
      Swarm.RelayService.Enabled = false;
      # reduce DHT overhead - client mode only announces, doesn't route for others
      Routing.Type = "autoclient";
    };
  };

  boot.kernel.sysctl."fs.inotify.max_user_watches" = 1048576;

  systemd.services.ipfs-pin-watcher = {
    description = "Auto-pin files to IPFS using inotify";
    after = [ "ipfs.service" ];
    requires = [ "ipfs.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Environment = [ "IPFS_PATH=/var/lib/ipfs" ];
      ExecStart = pinWatcherScript;
      Restart = "always";
      RestartSec = "10s";
      User = config.services.kubo.user;
      Group = config.services.kubo.group;
      SupplementaryGroups = [ "radio_container" ];
    };
  };

  networking.firewall.allowedTCPPorts = [
    4001 # IPFS swarm
    8089 # IPFS gateway
  ];
  networking.firewall.allowedUDPPorts = [
    4001 # IPFS swarm (QUIC)
  ];
}
