self: super: let
  lib = super.lib;

  # This callPackage will try to detect obsolete overrides.
  callPackage = path: args: let
    override =  super.callPackage path args;
    upstream = lib.optionalAttrs (override ? "name")
      (super.${(builtins.parseDrvName override.name).name} or {});
  in if upstream ? "name" &&
        override ? "name" &&
        builtins.compareVersions upstream.name override.name != -1
    then
      builtins.trace
        "Upstream `${upstream.name}' gets overridden by `${override.name}'."
        override
    else override;

   subdirsOf = path:
     lib.mapAttrs (name: _: path + "/${name}")
              (lib.filterAttrs (_: x: x == "directory") (builtins.readDir path));

in lib.mapAttrs (_: lib.flip callPackage {})
            (lib.filterAttrs (_: dir: lib.pathExists (dir + "/default.nix"))
                         (subdirsOf ./.))
