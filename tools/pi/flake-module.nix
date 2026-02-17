{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      piPkg = self.legacyPackages.${system}.llm.pi;

      # Pre-install pi plugins into a fake npm global prefix
      pluginPrefixRaw =
        pkgs.runCommand "pi-plugins-raw"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.cacert
            ];
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = "sha256-QZSVCJ0XirRz56v6ogxaB37c0bI8+OGEjrnqCFr/YI8=";
            impureEnvVars = [
              "http_proxy"
              "https_proxy"
            ];
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          }
          ''
            export HOME=$TMPDIR
            export npm_config_prefix=$out
            npm install -g pi-hooks shitty-extensions
          '';

      # Patch shitty-extensions:
      # - Remove the resistance extension (annoying terminator quote widget)
      # - Rebind ultrathink ctrl+u -> ctrl+shift+u (conflicts with deleteToLineStart)
      # - Rebind speedreading ctrl+r -> ctrl+shift+r (conflicts with renameSession)
      pluginPrefix = pkgs.runCommand "pi-plugins" { } ''
        cp -a ${pluginPrefixRaw} $out
        chmod -R u+w $out
        pkg=$out/lib/node_modules/shitty-extensions/package.json
        ${pkgs.jq}/bin/jq '.pi.extensions |= map(select(contains("resistance") | not))' "$pkg" > "$pkg.tmp"
        mv "$pkg.tmp" "$pkg"

        # Fix keybinding conflicts in extension source
        ${pkgs.gnused}/bin/sed -i 's/"ctrl+u"/"ctrl+shift+u"/' $out/lib/node_modules/shitty-extensions/extensions/ultrathink.ts
        ${pkgs.gnused}/bin/sed -i 's/"ctrl+r"/"ctrl+shift+r"/' $out/lib/node_modules/shitty-extensions/extensions/speedreading.ts
      '';
    in
    {
      packages.pi = self.wrapLib.makeWrapper {
        pkgs = pkgs;
        package = piPkg;
        runtimeInputs = [ pkgs.nodejs ];
        wrapper =
          { exePath, ... }:
          ''
            set -efu
            export npm_config_prefix="${pluginPrefix}"

            # Ensure settings.json has our plugins listed
            SETTINGS_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
            SETTINGS_FILE="$SETTINGS_DIR/settings.json"
            mkdir -p "$SETTINGS_DIR"

            # Add packages to settings if not already present
            if [ ! -f "$SETTINGS_FILE" ]; then
              echo '{"packages":["npm:pi-hooks","npm:shitty-extensions"]}' > "$SETTINGS_FILE"
            else
              for pkg in "npm:pi-hooks" "npm:shitty-extensions"; do
                if ! grep -q "$pkg" "$SETTINGS_FILE"; then
                  ${pkgs.jq}/bin/jq --arg p "$pkg" '.packages = ((.packages // []) + [$p] | unique)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
                  mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                fi
              done
            fi

            exec ${exePath} "$@"
          '';
      };
    };
}
