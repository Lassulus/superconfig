{ config, lib, ... }:
let
  hosts = lib.mapAttrs (machine: _: {
    ip =
      let
        zerotier_ip_path =
          config.clan.core.clanDir + "/vars/per-machine/${machine}/zerotier/zerotier-ip/value";
      in
      if builtins.pathExists zerotier_ip_path then builtins.readFile zerotier_ip_path else null;
  }) (builtins.readDir ../machines);

  filteredHosts = lib.filterAttrs (_name: host: host.ip != null) hosts;
in
{
  services.zerotierone.joinNetworks = [ "7c31a21e86f9a75c" ];
  services.zerotierone.localConf.settings = {
    interfacePrefixBlacklist = [
      "ygg"
      "mesh"
      "retiolum"
      "wiregrill"
    ];
    physical = {
      "10.243.0.0/16".blacklist = true;
      "10.244.0.0/16".blacklist = true;
      "42::/16".blacklist = true;
      "5d9::/7".blacklist = true;
    };
  };

  networking.extraHosts = lib.concatMapStringsSep "\n" (host: "${host.value.ip} ${host.name}.z") (
    lib.attrsToList filteredHosts
  );
}
