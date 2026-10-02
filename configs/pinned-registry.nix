{ self, ... }:
{
  nix.nixPath = [
    "nixpkgs=flake:nixpkgs"
  ];
  nix.registry = {
    nixpkgs.to = {
      type = "path";
      path = self.inputs.nixpkgs;
    };
  };
}
