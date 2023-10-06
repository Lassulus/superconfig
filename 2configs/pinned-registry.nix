{ self, ... }:
{
  nix.nixPath = [
    "nixpkgs=${self.inputs.nixpkgs}"
  ];
  nix.registry = {
    nixpkgs.to = {
      type = "path";
      path = self.inputs.nixpkgs;
    };
  };
}
