{ self, pkgs, ... }:
let
  kitty = self.packages.${pkgs.system}.kitty;
in
{
  # TODO: this plumbing should go away. Tools need a generic way to expose
  # their per-theme files (e.g. a `themes.<name>.<file>` passthru contract
  # that themes.nix collects into /etc/themes/<name>/) instead of every
  # 2configs/<tool>.nix hand-wiring environment.etc entries like this.
  environment.etc = {
    "themes/light/kitty-colors.conf".text = kitty.themes.light;
    "themes/dark/kitty-colors.conf".text = kitty.themes.dark;
  };
  environment.systemPackages = [ kitty ];
}
