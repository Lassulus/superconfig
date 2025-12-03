{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        let
          allPackages = lib.packagesFromDirectoryRecursive {
            inherit (pkgs) callPackage;
            directory = ./.;
          };
        in
        lib.filterAttrs (
          name: pkg: name != "flake-module" && lib.meta.availableOn pkgs.stdenv.hostPlatform pkg
        ) allPackages;
    };
}
