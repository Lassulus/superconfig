{ config, lib, pkgs, ... }:
let

  shares = {
    "/home/lass/sync" = [ "mors" "green" "coaxmetal" "ignavia" ]; # TODO add aergia
    "/home/lass/tmp/the_playlist" = [ "mors" "prism" "radio" ];
    # "/home/lass/.weechat" = [ "green" "mors" ];
    "/home/lass/decsync" = [ "mors" "green" "massulus" "massulus2" ];
  };

  machine_peers = lib.foldr (host: acc:
    if builtins.pathExists ../machines/${host}/facts/syncthing.pub then
      acc // { ${host}.id = lib.removeSuffix "\n" (builtins.readFile ../machines/${host}/facts/syncthing.pub); }
    else
    acc
  ) {} (lib.attrNames (builtins.readDir ../machines));

  all_peers = machine_peers // {
    "massulus".id = "R2EGJ5S-PQMETUP-C2UGXQG-A6VP7TB-NGSN3MV-C7OGSWT-SZ34L3X-H6IF6AQ";
    "massulus2".id = "OTJBJNO-VHBCVDL-QSELUS7-S6JDMYR-7WLE36A-6XSRSLP-VKYOYJJ-AHFGZAG";
  };

  used_peer_names = lib.unique (lib.filter lib.isString (lib.flatten (lib.mapAttrsToList (n: v: v.devices) config.services.syncthing.settings.folders)));
  used_peers = lib.filterAttrs (n: v: lib.elem n used_peer_names) all_peers;
in {
  services.syncthing = {
    enable = true;
    group = "syncthing";
    configDir = "/var/lib/syncthing";
    key = "${config.krebs.secret.directory}/syncthing.key";
    cert = "${config.krebs.secret.directory}/syncthing.cert";
    settings.devices = used_peers;
    settings.folders = lib.mapAttrs (share: devices: {
      enable = lib.elem config.networking.hostName devices;
      path = share;
      ignorePerms = false;
      versioning = {
        type = "trashcan";
        params = {
          cleanoutDays = "30";
        };
      };
      devices = devices;
    }) shares;
    user = "lass";
  };

  clanCore.facts.services.syncthing = {
    secret."syncthing.key" = { };
    secret."syncthing.cert" = { };
    public."syncthing.pub" = { };
    generator.path = with pkgs; [
      coreutils
      gnugrep
      syncthing
    ];
    generator.script = ''
      syncthing generate --config "$secrets"
      mv "$secrets"/key.pem "$secrets"/syncthing.key
      mv "$secrets"/cert.pem "$secrets"/syncthing.cert
      cat "$secrets"/config.xml | grep -oP '(?<=<device id=")[^"]+' | uniq > "$facts"/syncthing.pub
    '';
  };

  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 21027 ];
  };
}
