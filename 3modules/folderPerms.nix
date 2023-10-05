{ config, lib, pkgs, ... }:

#TODO: implement recursive mode maybe?
# enable different mods for files and folders

let
  inherit (pkgs)
    writeScript
  ;

  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    types
  ;

  cfg = config.lass.folderPerms;

  out = {
    options.lass.folderPerms = api;
    config = mkIf cfg.enable imp;
  };

  api = {
    enable = mkEnableOption "folder permissions";
    permissions = mkOption {
      type = with types; listOf (submodule ({
        options = {
          path = mkOption {
            type = str;
          };
          permission = mkOption {
            type = nullOr str;
            example = "755";
            description = ''
              basically anything that chmod takes as permission
            '';
            default = null;
          };
          owner = mkOption {
            type = nullOr str;
            example = "root:root";
            description = ''
              basically anything that chown takes as owner
            '';
            default = null;
          };
        };
      }));
    };
  };

  imp = {
    systemd.services.lass-folderPerms = {
      description = "lass-folderPerms";
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [
        coreutils
      ];

      restartIfChanged = true;

      serviceConfig = {
        type = "simple";
        RemainAfterExit = true;
        Restart = "always";
        ExecStart = "@${startScript}";
      };
    };
  };

  startScript = writeScript "lass-folderPerms" ''
    ${concatMapStringsSep "\n" writeCommand cfg.permissions}
  '';

  writeCommand = fperm:
    concatStringsSep "\n" [
      (buildPermission fperm)
      (buildOwner fperm)
    ];

  buildPermission = perm:
    #TODO: create folder maybe
    #TODO: check if permission is valid
    if (perm.permission == null) then
      ""
    else
      "chmod ${perm.permission} ${perm.path}"
  ;

  buildOwner = perm:
    #TODO: create folder maybe
    #TODO: check if owner/group valid
    if (perm.owner == null) then
      ""
    else
      "chown ${perm.owner} ${perm.path}"
  ;

in out
