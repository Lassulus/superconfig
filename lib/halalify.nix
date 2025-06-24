{ lib }:
/**
  Override unfree licenses to free ones in a derivation.

  This function takes a derivation and replaces any unfree license with lib.licenses.free.
  Note: This only works for simple packages. Complex packages with unfree dependencies
  in their build process (like firefox-bin -> firefox-bin-unwrapped) cannot be handled
  this way and need other approaches.

  # Example

  ```nix
  halalify pkgs.someUnfreePackage
  ```
*/
drv:
if !lib.isDerivation drv then
  drv
else
  let
    # Helper to check if a license is unfree
    isUnfreeLicense = license: lib.isAttrs license && license ? free && !license.free;

    # Helper to make a license free
    makeFreeLicense =
      license:
      if isUnfreeLicense license then
        lib.licenses.free
      else if lib.isList license then
        map makeFreeLicense license
      else
        license;
  in
  drv.overrideAttrs (old: {
    # Override the license
    meta =
      (old.meta or { })
      // lib.optionalAttrs (old.meta ? license) {
        license = makeFreeLicense old.meta.license;
      };
  })
