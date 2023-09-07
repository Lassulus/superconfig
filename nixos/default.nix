{ self, pkgs, ... }:
{
  imports = [
    ./2configs
    ./3modules
    self.inputs.stockholm.nixosModules.krebs
  ];
  nixpkgs.config.packageOverrides = import ./5pkgs pkgs; # TODO move into packages
  nixpkgs.overlays = [
    self.inputs.stockholm.overlays.default
    (import (self.inputs.stockholm.inputs.nix-writers + "/pkgs")) # TODO get rid of that overlay
  ];
}
