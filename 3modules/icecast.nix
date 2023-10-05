{ config, lib, pkgs, ... }:
let
  cfg = config.lass.icecast;

  format = pkgs.formats.json {};
in
{
  options.lass.icecast = {
    enable = lib.mkEnableOption "icecast";
    configFile = lib.mkOption {
      type = pkgs.stockholm.lib.types.absolute-pathname;
      default = pkgs.writeText "icecast.xml" ''
        <icecast>
        </icecast>
      '';
    };
    settings = lib.mkOption {
      description = lib.mdDoc "icecast.xml as a nix attrset."
      type = lib.types.submodule {
        freeformType = format.type;
      }
    };
  };
}
