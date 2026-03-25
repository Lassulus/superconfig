{ self, ... }:
{
  flake.wrapperModules.workspace-manager =
    {
      config,
      lib,
      pkgs,
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
        };
      };

      # Generate a directory with JSON files for each declared workspace
      systemConfigDir = pkgs.linkFarm "workspace-manager-configs" (
        lib.mapAttrsToList (name: ws: {
          name = "${name}.json";
          path = pkgs.writeText "${name}.json" (builtins.toJSON { inherit (ws) directory; });
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
              dev = { directory = "/home/user/src/myproject"; };
              music = { directory = "/home/user/Music"; };
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
            ];
          };
        };
      };
    };

  perSystem =
    {
      pkgs,
      ...
    }:
    let
      python = pkgs.python3;
    in
    {
      packages.workspace-manager =
        (pkgs.writeShellApplication {
          name = "workspace-manager";
          runtimeInputs = [
            pkgs.socat
            pkgs.jq
          ];
          text = builtins.readFile ./workspace-manager.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };

      packages.workspace-menu = pkgs.writeShellApplication {
        name = "workspace-menu";
        runtimeInputs = [
          pkgs.sway
          pkgs.jq
          self.packages.${pkgs.system}.menu
          pkgs.libnotify
          pkgs.findutils
          pkgs.gnused
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.firefox
        ];
        text = builtins.readFile ./workspace-menu.sh;
      };

      packages.workspace-manager-daemon = pkgs.stdenv.mkDerivation {
        pname = "workspace-manager-daemon";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.ruff
          python.pkgs.mypy
        ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ruff check daemon.py
          ruff format --check daemon.py
          mypy --strict daemon.py
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp daemon.py $out/bin/workspace-manager-daemon
          chmod +x $out/bin/workspace-manager-daemon
          wrapProgram $out/bin/workspace-manager-daemon \
            --prefix PATH : ${python}/bin:${pkgs.sway}/bin
          runHook postInstall
        '';
        meta.mainProgram = "workspace-manager-daemon";
      };

      # Open Firefox for the current workspace
      packages.workspace-browser = pkgs.writeShellScriptBin "workspace-browser" ''
        exec firefox "$@"
      '';

      # Native messaging host for the workspace-tabs Firefox extension
      packages.workspace-tabs-native-host = pkgs.stdenv.mkDerivation {
        pname = "workspace-tabs-native-host";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.ruff
          python.pkgs.mypy
        ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ruff check workspace-tabs-host.py
          ruff format --check workspace-tabs-host.py
          mypy --strict workspace-tabs-host.py
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/lib/mozilla/native-messaging-hosts
          cp workspace-tabs-host.py $out/bin/workspace-tabs-host
          chmod +x $out/bin/workspace-tabs-host
          wrapProgram $out/bin/workspace-tabs-host \
            --prefix PATH : ${python}/bin:${pkgs.sway}/bin

          cat > $out/lib/mozilla/native-messaging-hosts/workspace_tabs.json <<EOF
          {
            "name": "workspace_tabs",
            "description": "Native messaging host for Workspace Tabs extension",
            "path": "$out/bin/workspace-tabs-host",
            "type": "stdio",
            "allowed_extensions": ["workspace-tabs@workspace-manager"]
          }
          EOF
          runHook postInstall
        '';
      };

      # Firefox extension for workspace tab management (packaged as .xpi)
      packages.workspace-tabs-extension =
        pkgs.runCommand "workspace-tabs-extension"
          {
            nativeBuildInputs = [ pkgs.zip ];
          }
          ''
            mkdir -p $out
            cd ${./firefox-extension}
            zip -r "$out/workspace-tabs@workspace-manager.xpi" ./*
          '';
    };
}
