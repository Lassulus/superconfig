# Copied from stockholm krebs/3modules/reaktor2.nix (cc283503); the daemon is
# pkgs/reaktor2, stockholm's packages output does not include it.
{
  config,
  pkgs,
  self,
  ...
}:
with self.inputs.stockholm.lib;
{

  options.krebs.reaktor2 = mkOption {
    default = { };
    type = types.attrsOf (
      types.submodule (
        self:
        let
          name = self.config._module.args.name;
        in
        {
          options = {
            nick = mkOption {
              default = name;
              # TODO types.irc.nickname
              type = types.str;
            };
            hostname = mkOption {
              default = "irc.r";
              type = types.hostname;
            };
            port = mkOption {
              default = "6667";
              type = types.str;
            };
            plugins = mkOption {
              default = [ ];
              type = types.listOf types.attrs;
            };
            stateDir = mkOption {
              default = "/var/lib/${self.config.username}";
              defaultText = "/var/lib/‹username›";
              readOnly = true;
              type = types.absolute-pathname;
            };
            systemd-service-name = mkOption {
              default = "reaktor2${optionalString (name != "default") "-${name}"}";
              defaultText = "reaktor2-‹name› or just reaktor2 if ‹name› is \"default\"";
              type = types.filename;
            };
            sendDelaySec = mkOption {
              default = 0.7;
              type = types.nullOr types.float;
            };
            username = mkOption {
              default = self.config.systemd-service-name;
              defaultText = "‹systemd-service-name›";
              type = types.username;
            };
            useTLS = mkOption {
              default = self.config.port == "6697";
              type = types.bool;
            };
            API.listen = mkOption {
              default = null;
              type = types.nullOr types.str;
            };
          };
        }
      )
    );
  };

  config = {
    systemd.services = flip mapAttrs' config.krebs.reaktor2 (
      _: cfg:
      nameValuePair cfg.systemd-service-name {
        after = [ "network.target" ];
        environment = {
          LC_ALL = "en_US.UTF-8";
        };
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = cfg.username;
          Group = "reaktor2";
          DynamicUser = true;
          StateDirectory = cfg.username;
          #ExecStartPre = [
          #  (pkgs.writers.writeDash "test-dynamic-user" ''
          #    set -efux
          #    ${pkgs.coreutils}/bin/id
          #  '')
          #];
          ExecStart =
            let
              configFile = pkgs.writers.writeJSON configFileName configValue;
              configFileName = "${cfg.systemd-service-name}.config.json";
              configValue = stripAttr (
                recursiveUpdate {
                  logTime = false;
                } (removeAttrs cfg [ "_module" ])
              );
            in
            "${self.packages.${pkgs.stdenv.hostPlatform.system}.reaktor2}/bin/reaktor ${configFile}";
          Restart = "always";
          RestartSec = "30";
        };
      }
    );
  };
}
