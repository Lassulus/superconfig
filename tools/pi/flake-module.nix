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
              hash = "sha256-IYXckWXmRsX62aQANatkcu2kV+PXT5mNB2ONpJsOPMI=";
            }
            {
              source = "npm:shitty-extensions";
              hash = "sha256-OJZezuRDUiKysfkjJxeA6BjGohFR/+uVg611jGaRTV0=";
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
          ${pkgs.python3}/bin/python3 ${./patch-permission-sound.py} \
            $out/lib/node_modules/pi-hooks/permission/permission.ts \
            ${pkgs.pipewire}/bin/pw-play
        '';
      };
    in
    {
      packages.pi = pi.wrapper;
    };
}
