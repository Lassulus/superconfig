{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      pi = inputs.wrappers.lib.wrapModule {
        imports = [ self.wrapperModules.pi ];
        inherit pkgs;

        settings = {
          packages = [
            {
              source = "npm:pi-hooks";
              version = "1.0.3";
              hash = "sha256-jU3akfqsWgjvOG+8+Md2qEzkXp48LUaXVncpUMXxy7s=";
              deps = [
                {
                  source = "npm:shell-quote";
                  version = "1.8.3";
                  hash = "sha256-32QLNUuvjigj1scqLlCVFTfgS3MHm9dBjPk9iVB+IsE=";
                }
                {
                  source = "npm:vscode-languageserver-protocol";
                  version = "3.17.5";
                  hash = "sha256-dHPrLSFj8/i+oJZE+dgDeJoZXllrZdOUbEFX5YPjzMg=";
                  deps = [
                    {
                      source = "npm:vscode-jsonrpc";
                      version = "8.2.0";
                      hash = "sha256-PaRFMcOY8VRQdMtyjjWagi81ufiscXHIR/QvByi5x8s=";
                    }
                    {
                      source = "npm:vscode-languageserver-types";
                      version = "3.17.5";
                      hash = "sha256-1nP55/i75RNRvlHFjzLU3PqXpnDruGvGMzaDlMYJysA=";
                    }
                  ];
                }
              ];
            }
            {
              source = "npm:shitty-extensions";
              version = "1.0.9";
              hash = "sha256-g26MZ5x4HUcDai4SXPaOEhqgGGqzAI68znnsCbKJv7E=";
              extensions = [ "!extensions/resistance.ts" ];
            }
          ];
          defaultProvider = "anthropic";
          defaultModel = "claude-opus-4-6";
          defaultThinkingLevel = "medium";
          permissionLevel = "low";
          permissionMode = "ask";
          permissionConfig.overrides.minimal = [
            "nix build *"
            "nix eval *"
            "nix fmt *"
          ];
        };

        pluginOverrides = ''
          # Fix keybinding conflicts in extension source
          ${pkgs.gnused}/bin/sed -i 's/"ctrl+u"/"ctrl+shift+u"/' $out/lib/node_modules/shitty-extensions/extensions/ultrathink.ts
          ${pkgs.gnused}/bin/sed -i 's/"ctrl+r"/"ctrl+shift+r"/' $out/lib/node_modules/shitty-extensions/extensions/speedreading.ts

          # Patch permission extension to use pw-play for peon sounds on Linux
          ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            ${pkgs.python3}/bin/python3 ${./patch-permission-sound.py} \
              $out/lib/node_modules/pi-hooks/permission/permission.ts \
              ${pkgs.pipewire}/bin/pw-play
          ''}
        '';
      };
    in
    {
      packages.pi = pi.wrapper;
    };
}
