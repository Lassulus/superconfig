{ ... }:
{
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
            --prefix PATH : ${python}/bin:${pkgs.sway}/bin:${pkgs.tmux}/bin
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
