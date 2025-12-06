{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        let
          # Wrapper that handles platform-incompatible packages by:
          # 1. Catching eval errors during callPackage
          # 2. Filtering based on meta.platforms
          platformAwareCallPackage =
            path: args:
            let
              result = builtins.tryEval (pkgs.callPackage path args);
              pkg = result.value;
              isSupported = result.success && lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;
            in
            if isSupported then pkg else null;

          allPackages = lib.packagesFromDirectoryRecursive {
            callPackage = platformAwareCallPackage;
            directory = ./.;
          };
        in
        lib.filterAttrs (name: pkg: name != "flake-module" && pkg != null) allPackages;
    };
}
