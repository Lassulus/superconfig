{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        let
          allPackages = lib.mapAttrs (
            name: _:
            let
              pkgDir = ./. + "/${name}";
              hasPackageNix = builtins.pathExists (pkgDir + "/package.nix");
              hasDefaultNix = builtins.pathExists (pkgDir + "/default.nix");
            in
            if hasPackageNix then
              pkgs.callPackage (pkgDir + "/package.nix") { }
            else if hasDefaultNix then
              builtins.trace "Warning: ${name} is using deprecated default.nix, please rename to package.nix" (
                pkgs.callPackage pkgDir { }
              )
            else
              throw "Package ${name} has neither package.nix nor default.nix"
          ) (lib.filterAttrs (_n: v: v == "directory") (builtins.readDir ./.));
        in
        # Filter packages based on meta.platforms
        lib.filterAttrs (_name: pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg) allPackages;
    };
}
