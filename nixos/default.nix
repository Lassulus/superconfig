{ self, pkgs, ... }:
{
  imports = [
    ./2configs
    ./3modules
    self.inputs.stockholm.nixosModules.krebs
  ];
  nixpkgs.config.packageOverrides = import ./5pkgs pkgs;
  nixpkgs.overlays = [
    self.inputs.stockholm.overlays.default
    (import (self.inputs.stockholm.inputs.nix-writers + "/pkgs"))
  ];
}
