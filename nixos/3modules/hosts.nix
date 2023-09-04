{ config, lib, ... }:

with lib;

{
  options.lass.hosts = mkOption {
    type = types.attrsOf types.host;
    default =
      filterAttrs (_: host: host.owner.name == "lass" && host.ci)
      config.krebs.hosts;
  };
}
