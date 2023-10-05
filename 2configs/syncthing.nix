{ config, lib, pkgs, ... }: with lib;
let
  mk_peers = mapAttrs (n: v: { id = v.syncthing.id; });

  all_peers = filterAttrs (n: v: v.syncthing.id != null) config.krebs.hosts;
  used_peer_names = unique (filter isString (flatten (mapAttrsToList (n: v: v.devices) config.services.syncthing.folders)));
  used_peers = filterAttrs (n: v: elem n used_peer_names) all_peers;
in {
  services.syncthing = {
    enable = true;
    group = "syncthing";
    configDir = "/var/lib/syncthing";
    key = "${config.krebs.secret.directory}/syncthing.key";
    cert = "${config.krebs.secret.directory}/syncthing.cert";
    # workaround for infinite recursion on unstable, remove in 23.11
    settings.devices = mk_peers used_peers;
  };

  clanCore.secrets.syncthing = {
    secrets."syncthing.key" = { };
    secrets."syncthing.cert" = { };
    facts."syncthing.pub" = { };
    generator = ''
      ${pkgs.syncthing}/bin/syncthing generate --config "$secrets"
      mv "$secrets"/key.pem "$secrets"/syncthing.key
      mv "$secrets"/cert.pem "$secrets"/syncthing.cert
      cat "$secrets"/config.xml | ${pkgs.gnugrep}/bin/grep -oP '(?<=<device id=")[^"]+' | uniq > "$facts"/syncthing.pub
    '';
  };

  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 22000"; target = "ACCEPT";}
    { predicate = "-p udp --dport 21027"; target = "ACCEPT";}
  ];
  system.activationScripts.syncthing-home = mkDefault ''
    ${pkgs.coreutils}/bin/chmod a+x /home/lass
  '';
}
