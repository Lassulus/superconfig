{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.lass.workspace-manager;

  workspaceType = lib.types.submodule {
    options = {
      directory = lib.mkOption {
        type = lib.types.str;
        description = "Directory to use for this workspace";
      };
      on_enter = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands to run when entering this workspace";
      };
      on_leave = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands to run when leaving this workspace";
      };
      on_create = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands to run in a tmux session when the workspace is first entered. Each command gets its own tmux window with visible logs. Reattach with: tmux attach -t ws-<name>";
      };
    };
  };

  # Generate a directory with JSON files for each declared workspace
  systemConfigDir = pkgs.linkFarm "workspace-manager-configs" (
    lib.mapAttrsToList (name: ws: {
      name = "${name}.json";
      path = pkgs.writeText "${name}.json" (
        builtins.toJSON {
          inherit (ws) directory on_enter on_leave on_create;
        }
      );
    }) cfg.workspaces
  );
in
{
  options.lass.workspace-manager = {
    enable = lib.mkEnableOption "workspace manager daemon for sway";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.workspace-manager-daemon;
      description = "The workspace-manager-daemon package to use";
    };

    workspaces = lib.mkOption {
      type = lib.types.attrsOf workspaceType;
      default = { };
      description = "Declarative workspace configurations (take precedence over user configs)";
      example = lib.literalExpression ''
        {
          dev = {
            directory = "/home/user/src/myproject";
            on_enter = [ "notify-send 'Entered dev workspace'" ];
          };
          music = {
            directory = "/home/user/Music";
          };
        }
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "~/workspaces";
      description = "Directory containing user workspace configuration files";
    };

    defaultDirectory = lib.mkOption {
      type = lib.types.str;
      default = "~";
      description = "Default directory for workspaces without configuration";
    };

    terminalCommand = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
      description = "Terminal emulator to use for on_create commands. Must support '-T title' for setting the window title.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.workspace-manager = {
      description = "Workspace Manager Daemon";
      partOf = [ "sway-session.target" ];
      wantedBy = [ "sway-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/workspace-manager-daemon";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "WORKSPACE_MANAGER_CONFIG_DIR=${cfg.configDir}"
          "WORKSPACE_MANAGER_SYSTEM_CONFIG_DIR=${systemConfigDir}"
          "WORKSPACE_MANAGER_DEFAULT_DIR=${cfg.defaultDirectory}"
          "WORKSPACE_MANAGER_TERMINAL=${cfg.terminalCommand}"
        ];
      };
    };
  };
}
