{ lib }:
/**
  Strip a derivation's `meta.knownVulnerabilities`, so the nixpkgs
  insecure-package check accepts it.

  Useful when `nixpkgs.config.permittedInsecurePackages` is unsuitable —
  notably across NixOS modules, since `nixpkgs.config` merges via
  `recursiveUpdate` and list values get clobbered, not concatenated.
  An overlay that secureifies the offending package (or its insecure
  dependency) is a per-module fix that composes cleanly via
  `nixpkgs.overlays`.

  # Example

  ```nix
  # in a NixOS module:
  nixpkgs.overlays = [
    (_final: prev: { olm = self.lib.secureify prev.olm; })
  ];
  ```
*/
drv:
if !lib.isDerivation drv then
  drv
else
  drv.overrideAttrs (old: {
    meta = (old.meta or { }) // {
      knownVulnerabilities = [ ];
    };
  })
