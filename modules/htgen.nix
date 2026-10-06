# Copied from stockholm krebs/3modules/htgen.nix (cc283503); htgen now comes
# from stockholm's packages output instead of its overlay. Users and groups
# get their ids from NixOS instead of stockholm's genid.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:

with lib;
let
  optionalAttr = name: value: if name != null then { ${name} = value; } else { };

  cfg = config.krebs.htgen;

  out = {
    options.krebs.htgen = api;
    config = imp;
  };

  api = mkOption {
    default = { };
    type = types.attrsOf (
      types.submodule (
        { config, ... }: {
          options = {
            enable = mkEnableOption "krebs.htgen-${config._module.args.name}";

            name = mkOption {
              # POSIX portable filename, like stockholm's types.username
              type = types.strMatching "[0-9A-Za-z._][0-9A-Za-z._-]*";
              default = config._module.args.name;
            };

            package = mkOption {
              default = self.inputs.stockholm.packages.${pkgs.stdenv.hostPlatform.system}.htgen;
              type = types.package;
            };

            port = mkOption {
              type = types.port;
            };

            script = mkOption {
              type = types.nullOr types.str;
              default = null;
            };

            scriptFile = mkOption {
              type = types.nullOr (types.either types.package types.path);
              default = null;
            };

            user = mkOption {
              type = types.submodule (
                { config, ... }:
                {
                  options = {
                    name = mkOption {
                      type = types.strMatching "[0-9A-Za-z._][0-9A-Za-z._-]*";
                    };
                    home = mkOption {
                      type = types.path;
                      # as stockholm's types.user
                      default = "/home/${config.name}";
                    };
                  };
                }
              );
              default = {
                name = "htgen-${config.name}";
                home = "/var/lib/htgen-${config.name}";
              };
              defaultText = {
                name = "htgen-‹name›";
                home = "/var/lib/htgen-‹name›";
              };
            };
          };
        }
      )
    );
  };
  imp = {

    systemd.services = mapAttrs' (
      name: htgen:
      nameValuePair "htgen-${name}" {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = {
          HTGEN_PORT = toString htgen.port;
        }
        // optionalAttr "HTGEN_SCRIPT" htgen.script
        // optionalAttr "HTGEN_SCRIPT_FILE" htgen.scriptFile;
        serviceConfig = {
          SyslogIdentifier = "htgen";
          User = htgen.user.name;
          PrivateTmp = true;
          Restart = "always";
          ExecStart = "${htgen.package}/bin/htgen --serve";
        };
      }
    ) cfg;

    users.users = mapAttrs' (
      name: htgen:
      nameValuePair htgen.user.name {
        inherit (htgen.user) home name;
        group = htgen.user.name;
        createHome = true;
        isSystemUser = true;
      }
    ) cfg;

    users.groups = mapAttrs' (
      _name: htgen:
      nameValuePair htgen.user.name {
        name = htgen.user.name;
      }
    ) cfg;

  };
in
out
