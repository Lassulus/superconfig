{ config, lib, pkgs, ... }:
let

  shares = {
    "/home/lass/sync" = [ "mors" "xerxes" "green" "blue" "coaxmetal" "aergia" "ignavia" ];
    "/home/lass/tmp/the_playlist" = [ "mors" "phone" "prism" "omo" "radio" ];
    # "/home/lass/.weechat" = [ "green" "mors" ];
    "/home/lass/decsync" = [ "mors" "blue" "green" "phone" "massulus" ];
  };

  mk_peers = lib.mapAttrs (n: v: { id = v.syncthing.id; });

  all_peers = lib.filterAttrs (n: v: v.syncthing.id != null) config.krebs.hosts;
  used_peer_names = lib.unique (lib.filter lib.isString (lib.flatten (lib.mapAttrsToList (n: v: v.devices) config.services.syncthing.settings.folders)));
  used_peers = lib.filterAttrs (n: v: lib.elem n used_peer_names) all_peers;
in {
  services.syncthing = {
    enable = true;
    group = "syncthing";
    configDir = "/var/lib/syncthing";
    key = "${config.krebs.secret.directory}/syncthing.key";
    cert = "${config.krebs.secret.directory}/syncthing.cert";
    # workaround for infinite recursion on unstable, remove in 23.11
    settings.devices = mk_peers used_peers;
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
