{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages = lib.packagesFromDirectoryRecursive {
        inherit (pkgs) callPackage;
        directory = ./.;
      };
    };
}
