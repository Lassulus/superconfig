let
  pkgs = import <nixpkgs> {};

  mkNixosManual = let
    inherit pkgs;
    inherit (pkgs) lib;
    # Reduces the attrs from a package set so broken packages evaluate (I think?)
    scrubDerivations = namePrefix: pkgSet: lib.mapAttrs
      (name: value:
        let wholeName = "${namePrefix}.${name}"; in
        if lib.isAttrs value then
          scrubDerivations wholeName value
          // (lib.optionalAttrs (lib.isDerivation value) { outPath = "\${${wholeName}}"; })
        else value
      )
      pkgSet;
    # An evluation of the specified system version with only the modules and no config
    scrubbedEval = lib.evalModules {
      modules = [
        {
          #imports = [ ./default.nix ];
        }
      ] ++ (import (pkgs.path + /nixos/modules/module-list.nix));
      # Forward the filtered package set and the modules path
      specialArgs = {
        pkgs = scrubDerivations "pkgs" pkgs;
        modulesPath = pkgs.path + /nixos/modules;
      };
    };
  in (import (pkgs.path + /nixos/doc/manual)) rec {
    # From parent scope
    inherit (scrubbedEval) config;
    # From let
    inherit pkgs;
    version = scrubbedEval.config.system.nixos.release;
    revision = "release-${version}";

    extraSources = [ ../. ];
    options = scrubbedEval.options;
  };
in mkNixosManual
