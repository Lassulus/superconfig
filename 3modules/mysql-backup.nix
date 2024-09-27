{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.lass.mysqlBackup;

  out = {
    options.lass.mysqlBackup = api;
    config = mkIf cfg.enable imp;
  };

  api = {
    enable = mkEnableOption "mysqlBackup";
    config = mkOption {
      type =
        with types;
        attrsOf (
          submodule (
            { config, ... }:
            {
              options = {
                name = mkOption {
                  type = types.str;
                  default = config._module.args.name;
                };
                startAt = mkOption {
                  type = with types; nullOr str; # TODO systemd.time(7)'s calendar event
                  default = "*-*-* 01:15:00";
                };
                user = mkOption {
                  type = str;
                  default = "root";
                };
                password = mkOption {
                  type = nullOr str;
                  default = null;
                  description = ''
                    path to a file containing the mysqlPassword for the specified user.
                  '';
                };
                databases = mkOption {
                  type = listOf str;
                  default = [ ];
                };
                location = mkOption {
                  type = str;
                  default = "/backups/sql_dumps";
                };
              };
            }
          )
        );
      description = "configuration for mysqlBackup";
    };
  };

  imp = {

    services.mysql.ensureUsers = [
      {
        ensurePermissions = {
          "*.*" = "ALL";
        };
        name = "root";
      }
    ];

    systemd.services = mapAttrs' (
      _: plan:
      nameValuePair "mysqlBackup-${plan.name}" {
        path = with pkgs; [
          mysql
          gzip
        ];
        serviceConfig = rec {
          ExecStart = start plan;
          SyslogIdentifier = ExecStart.name;
          Type = "oneshot";
          User = plan.user;
        };
        startAt = plan.startAt;
      }
    ) cfg.config;
  };

  start =
    plan:
    let
      backupScript = plan: db: ''
        mkdir -p ${plan.location}
        mysqldump -u ${plan.user} ${
          optionalString (plan.password != null) "-p$(cat ${plan.password})"
        } ${db} | gzip -c > ${plan.location}/${db}.gz
      '';

    in
    pkgs.pkgs.writeDash "mysqlBackup.${plan.name}" ''
      ${concatMapStringsSep "\n" (backupScript plan) plan.databases}
    '';

in
out
