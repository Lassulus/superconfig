{ lib, ... }:
let
  hosts = lib.mapAttrs (machine: _: {
    ip = if builtins.pathExists ../machines/${machine}/facts/zerotier-ip then
      builtins.readFile ../machines/${machine}/facts/zerotier-ip
    else
      null;
  }) (builtins.readDir ../machines);

  filteredHosts = lib.filterAttrs (name: host: host.ip != null) hosts;

in
{
  clan.networking.zerotier.networkId = "7c31a21e86f9a75c";

  networking.extraHosts = lib.concatMapStringsSep "\n" (host:
    "${host.value.ip} ${host.name}.z"
  ) (lib.attrsToList filteredHosts);
}
