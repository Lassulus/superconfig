{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      gameDirs = builtins.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.)
      );

      buildGame = name:
        let
          result = builtins.tryEval (pkgs.callPackage ./${name} { });
        in
        if result.success then result.value else null;

      games = lib.filterAttrs (_: v: v != null) (
        lib.genAttrs gameDirs buildGame
      );
    in
    {
      # Expose via legacyPackages so `nix run .#games.haunted-ps1-demo-disc-2021` works
      legacyPackages.games = games;
    };
}
