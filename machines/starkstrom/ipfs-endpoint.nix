{
  config,
  pkgs,
  ...
}:
let
  api = "/ip4/127.0.0.1/tcp/5001";
  ipfs = "${pkgs.kubo}/bin/ipfs";
  uploadServer = pkgs.writers.writePython3Bin "ipfs-upload-server" {
    flakeIgnore = [ "E501" ];
  } ./ipfs_upload.py;
in
{
  imports = [ ../../2configs/nginx.nix ];

  # scratch area for in-flight uploads (extracted, added, then deleted)
  systemd.tmpfiles.rules = [
    "d /var/lib/ipfs/incoming 0700 ${config.services.kubo.user} ${config.services.kubo.group} -"
  ];

  # anonymous tarball -> `ipfs add` (into the blockstore) -> pinned -> returns CID
  systemd.services.ipfs-upload = {
    description = "Anonymous tarball -> IPFS pinning endpoint";
    after = [ "ipfs.service" ];
    requires = [ "ipfs.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Environment = [
        "IPFS_BIN=${pkgs.kubo}/bin/ipfs"
        "IPFS_API=${api}"
        "STAGING=/var/lib/ipfs/incoming"
        "ROOTS_FILE=/var/lib/ipfs/gc-roots"
        "GATEWAY_BASE=https://starkstrom.lassul.us"
        "BIND=127.0.0.1"
        "PORT=8090"
        "MAX_BYTES=8589934592" # 8 GiB compressed upload
        "MAX_EXTRACT_BYTES=21474836480" # 20 GiB extracted
        "DISK_PATH=/var/lib/ipfs"
        "MIN_FREE_BYTES=322122547200" # refuse uploads with <300 GiB free
      ];
      ExecStart = "${uploadServer}/bin/ipfs-upload-server";
      Restart = "always";
      RestartSec = "10s";
      User = config.services.kubo.user;
      Group = config.services.kubo.group;
    };
  };

  # public vhost (starkstrom's own name): writable upload at /, read-only gateway at /ipfs/
  services.nginx.virtualHosts."starkstrom.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/ipfs/".extraConfig = ''
      proxy_pass http://127.0.0.1:8089;
      proxy_set_header Host $host;
    '';
    locations."/".extraConfig = ''
      proxy_pass http://127.0.0.1:8090;
      client_max_body_size 8g;
      proxy_request_buffering off;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
    '';
  };

  # Explicit GC + gc-root management. Pins are the GC roots (persisted by kubo);
  # `ipfs-gc` reclaims everything not reachable from a pin. Prune first with
  # `ipfs-roots rm <cid>`, then `ipfs-gc`.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ipfs-gc" ''
      exec ${ipfs} --api ${api} repo gc "$@"
    '')
    (pkgs.writeShellScriptBin "ipfs-roots" ''
      cmd="''${1-list}"
      shift || true
      case "$cmd" in
        list) exec ${ipfs} --api ${api} pin ls --type=recursive ;;
        ledger) exec ${pkgs.coreutils}/bin/cat /var/lib/ipfs/gc-roots ;;
        rm) exec ${ipfs} --api ${api} pin rm "$@" ;;
        *)
          echo "usage: ipfs-roots [list|ledger|rm <cid>...]" >&2
          exit 1
          ;;
      esac
    '')
  ];
}
