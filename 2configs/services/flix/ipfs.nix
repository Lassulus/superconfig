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
  downloadRoot = "/var/lib/ipfs/download";
  flixIndexMfs = "/flix-index";
  dirtyFlag = "/var/lib/ipfs/flix-index.dirty";
  ipnsNameFile = "/var/lib/ipfs/flix-index.name";

  pinWatcherScript = pkgs.writers.writeBash "ipfs-pin-watcher" ''
    set -efu

    IPFS="${pkgs.kubo}/bin/ipfs"
    INOTIFYWAIT="${pkgs.inotify-tools}/bin/inotifywait"
    CID_MAP="${cidMapFile}"
    DOWNLOAD_ROOT="${downloadRoot}"
    FLIX_INDEX="${flixIndexMfs}"
    DIRTY_FLAG="${dirtyFlag}"
    IPNS_NAME_FILE="${ipnsNameFile}"

    touch "$CID_MAP"

    log() {
      echo "[$(date -Iseconds)] $*"
    }

    mark_dirty() {
      touch "$DIRTY_FLAG"
    }

    # strip $DOWNLOAD_ROOT/ prefix to get the relative path used inside MFS
    relpath() {
      echo "''${1#$DOWNLOAD_ROOT/}"
    }

    mfs_add() {
      local cid="$1" path="$2"
      local rel dir
      rel=$(relpath "$path")
      dir=$(${pkgs.coreutils}/bin/dirname "$rel")
      # kubo's `files rm/cp/mkdir` write detailed errors to stdout, not
      # stderr, so both FDs need redirection to keep backfill quiet.
      $IPFS files mkdir -p "$FLIX_INDEX/$dir" >/dev/null 2>&1 || true
      $IPFS files rm "$FLIX_INDEX/$rel" >/dev/null 2>&1 || true
      $IPFS files cp "/ipfs/$cid" "$FLIX_INDEX/$rel" >/dev/null 2>&1 || true
      mark_dirty
    }

    mfs_rm() {
      local path="$1"
      local rel
      rel=$(relpath "$path")
      $IPFS files rm "$FLIX_INDEX/$rel" >/dev/null 2>&1 || true
      mark_dirty
    }

    # ensure IPNS key + MFS root exist (idempotent)
    if ! $IPFS key list | ${pkgs.gnugrep}/bin/grep -qx flix-index; then
      log "Generating flix-index IPNS key"
      $IPFS key gen --type=ed25519 flix-index > "$IPNS_NAME_FILE" || true
    fi
    if [ -f "$IPNS_NAME_FILE" ]; then
      log "flix-index IPNS name: $(cat "$IPNS_NAME_FILE")"
    fi
    $IPFS files mkdir -p "$FLIX_INDEX" >/dev/null 2>&1 || true

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
      mfs_add "$cid" "$path"
    }

    remove_file() {
      local path="$1"
      cid=$(${pkgs.gawk}/bin/awk -v p="$path" '$0 ~ p {print $1; exit}' "$CID_MAP")
      if [ -n "$cid" ]; then
        log "Unpinning $cid ($path)"
        # remove from MFS first so the implicit MFS pin doesn't keep it alive
        mfs_rm "$path"
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
        mfs_rm "$path"
        $IPFS pin rm "$cid" 2>/dev/null || true
        ${pkgs.gnused}/bin/sed -i "\|^[^ ]* $path$|d" "$CID_MAP"
      fi
    done < "$CID_MAP"
    log "Cleanup complete"

    # backfill MFS index from cid-map.txt once (sentinel-guarded so we run
    # exactly once per machine, independently of whether the initial sync
    # happened to create any MFS entries incrementally).
    BACKFILL_SENTINEL="/var/lib/ipfs/flix-index.backfilled"
    if [ ! -f "$BACKFILL_SENTINEL" ]; then
      log "Backfilling MFS index from cid-map.txt..."
      n=0
      while IFS=' ' read -r cid path; do
        [ -f "$path" ] || continue
        # skip entries already present (idempotent re-runs)
        rel=$(relpath "$path")
        if $IPFS files stat "$FLIX_INDEX/$rel" >/dev/null 2>&1; then
          continue
        fi
        mfs_add "$cid" "$path"
        n=$((n + 1))
      done < "$CID_MAP"
      touch "$BACKFILL_SENTINEL"
      log "Backfill complete ($n entries added)"
    fi

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

  publishScript = pkgs.writers.writeBash "flix-index-publish" ''
    set -efu

    IPFS="${pkgs.kubo}/bin/ipfs"
    CID_MAP="${cidMapFile}"
    DOWNLOAD_ROOT="${downloadRoot}"
    FLIX_INDEX="${flixIndexMfs}"
    DIRTY_FLAG="${dirtyFlag}"

    [ -f "$DIRTY_FLAG" ] || exit 0

    # regenerate index.tsv from cid-map.txt
    tmp=$(${pkgs.coreutils}/bin/mktemp)
    printf 'cid\tpath\tsize\n' > "$tmp"
    while IFS=' ' read -r cid path; do
      [ -f "$path" ] || continue
      rel="''${path#$DOWNLOAD_ROOT/}"
      size=$(${pkgs.coreutils}/bin/stat -c %s "$path" 2>/dev/null || echo 0)
      printf '%s\t%s\t%s\n' "$cid" "$rel" "$size" >> "$tmp"
    done < "$CID_MAP"

    $IPFS files rm "$FLIX_INDEX/index.tsv" >/dev/null 2>&1 || true
    $IPFS files write --create --truncate "$FLIX_INDEX/index.tsv" < "$tmp"
    ${pkgs.coreutils}/bin/rm -f "$tmp"

    root=$($IPFS files stat --hash "$FLIX_INDEX")
    echo "Publishing $root to IPNS (flix-index)"
    $IPFS name publish --key=flix-index --lifetime=48h --ttl=1m "/ipfs/$root"
    # Announce the MFS root to the DHT so public gateways can find us.
    # MFS directory blocks are only kept alive by an implicit pin that
    # Provide.Strategy="pinned" ignores, so we provide them explicitly here.
    echo "Announcing $root to DHT"
    $IPFS routing provide "$root" >/dev/null 2>&1 || true
    ${pkgs.coreutils}/bin/rm -f "$DIRTY_FLAG"
  '';

  # Periodic reconciliation: walks cid-map.txt and repairs stale state for
  # files that no longer exist on disk. Protects against inotify event
  # drops (e.g. queue overflow during bulk renames/deletes) and any other
  # path that leaves cid-map/MFS out of sync with the filesystem.
  reconcileScript = pkgs.writers.writeBash "flix-index-reconcile" ''
    set -efu

    IPFS="${pkgs.kubo}/bin/ipfs"
    CID_MAP="${cidMapFile}"
    DOWNLOAD_ROOT="${downloadRoot}"
    FLIX_INDEX="${flixIndexMfs}"
    DIRTY_FLAG="${dirtyFlag}"

    [ -f "$CID_MAP" ] || exit 0

    # Rebuild cid-map in one pass, collecting stale entries to clean up.
    # Avoids sed regex issues with special chars like [ ] in paths.
    # Small race with pin-watcher's concurrent appends — any line the
    # watcher writes during this loop may be lost, but will be re-added
    # on the next inotify event or watcher restart.
    tmp=$(${pkgs.coreutils}/bin/mktemp)
    removed=0
    while IFS=' ' read -r cid path; do
      [ -n "$cid" ] || continue
      if [ -e "$path" ]; then
        echo "$cid $path" >> "$tmp"
      else
        rel="''${path#$DOWNLOAD_ROOT/}"
        $IPFS files rm "$FLIX_INDEX/$rel" >/dev/null 2>&1 || true
        $IPFS pin rm "$cid" >/dev/null 2>&1 || true
        removed=$((removed + 1))
      fi
    done < "$CID_MAP"

    if [ "$removed" -gt 0 ]; then
      ${pkgs.coreutils}/bin/mv "$tmp" "$CID_MAP"
      echo "reconciled: removed $removed stale entries"
      touch "$DIRTY_FLAG"
    else
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi
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
      # kubo 0.40 deprecated Reprovider in favor of Provide; the nixpkgs
      # module still injects a default Reprovider block, so null it out
      # explicitly or kubo refuses to start.
      Reprovider = null;
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
        LowWater = 100;
        HighWater = 400;
        GracePeriod = "20s";
      };
      Swarm.Transports.Network.TCP = true;
      Swarm.Transports.Network.QUIC = true;
      Swarm.ResourceMgr = {
        Enabled = true;
        MaxMemory = "2GB";
      };
      # disable relay to reduce overhead
      Swarm.RelayClient.Enabled = false;
      Swarm.RelayService.Enabled = false;
      # dhtclient: announces our provider records (so peers can find content
      # we host by CID) but does not serve DHT routing queries for others.
      # autoclient would skip provide announcements and make our content
      # invisible to bitswap.
      Routing.Type = "dhtclient";
      Provide = {
        Strategy = "pinned";
        DHT.Interval = "12h";
      };
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

  systemd.services.flix-index-publish = {
    description = "Publish flix MFS index to IPNS";
    after = [ "ipfs.service" ];
    requires = [ "ipfs.service" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = [ "IPFS_PATH=/var/lib/ipfs" ];
      ExecStart = publishScript;
      User = config.services.kubo.user;
      Group = config.services.kubo.group;
    };
  };

  systemd.timers.flix-index-publish = {
    description = "Publish flix MFS index to IPNS periodically";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
      Unit = "flix-index-publish.service";
    };
  };

  systemd.services.flix-index-reconcile = {
    description = "Reconcile flix MFS index / cid-map against filesystem";
    after = [ "ipfs.service" ];
    requires = [ "ipfs.service" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = [ "IPFS_PATH=/var/lib/ipfs" ];
      ExecStart = reconcileScript;
      User = config.services.kubo.user;
      Group = config.services.kubo.group;
    };
  };

  systemd.timers.flix-index-reconcile = {
    description = "Reconcile flix MFS index hourly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "1h";
      Unit = "flix-index-reconcile.service";
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
