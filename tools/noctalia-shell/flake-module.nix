{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      noctalia = inputs.wrappers.lib.wrapModule {
        imports = [ self.wrapperModules.noctalia-shell ];
        inherit pkgs;

        # Declarative settings merged into ~/.config/noctalia/settings.json
        # on every start. Anything not listed here remains user-mutable.
        settings = {
          hooks = {
            enabled = true;
            # Mirror noctalia's dark mode toggle to the system theme.
            darkModeChange = ''if [ "$1" = "true" ]; then switch-theme dark; else switch-theme light; fi'';
          };
        };

        settingsPatches = [
          # Show workspace names instead of indices in the bar.
          ''.bar.widgets.center |= map(if .id == "Workspace" then .labelMode = "name" else . end)''
        ];
      };
    in
    {
      packages.noctalia-shell = noctalia.wrapper;
    };
}
