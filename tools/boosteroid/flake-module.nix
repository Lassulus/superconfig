{
  perSystem =
    { pkgs, ... }:
    let
      boosteroid = pkgs.callPackage ./package.nix { };
    in
    {
      packages.boosteroid = boosteroid;
    };
}
