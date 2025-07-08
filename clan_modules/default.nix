{
  nixpkgs,
  ...
}:
let
  # Get all .nix files in this directory except default.nix
  nixFiles = builtins.filter (name: name != "default.nix" && nixpkgs.lib.hasSuffix ".nix" name) (
    builtins.attrNames (builtins.readDir ./.)
  );

  # Convert filename to module name (remove .nix extension)
  nameFromPath = path: nixpkgs.lib.removeSuffix ".nix" path;

  # Import each module
  importModule = name: import (./. + "/${name}");
in
# Create attribute set with all modules
nixpkgs.lib.listToAttrs (
  map (file: {
    name = nameFromPath file;
    value = importModule file;
  }) nixFiles
)
