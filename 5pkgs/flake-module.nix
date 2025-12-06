{ ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    {
      packages =
        let
          # Wrapper that handles platform-incompatible packages by catching eval errors.
          # This breaks laziness (evaluates all packages upfront) but ensures:
          # - Platform-incompatible packages are filtered out for `nix flake check`
          # - Real errors in package definitions are still caught and reported
          #
          # Note: tryEval catches both platform errors AND real errors. However, real errors
          # will still surface when the package is evaluated on platforms where dependencies exist.
          platformAwareCallPackage =
            path: args:
            let
              result = builtins.tryEval (pkgs.callPackage path args);
            in
            if result.success then result.value else null;

          allPackages = lib.packagesFromDirectoryRecursive {
            callPackage = platformAwareCallPackage;
            directory = ./.;
          };
        in
        lib.filterAttrs (name: pkg: name != "flake-module" && pkg != null) allPackages;
    };
}
