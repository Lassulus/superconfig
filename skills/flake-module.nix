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
      skillDirs = builtins.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.)
      );

      buildSkill = name:
        let
          result = builtins.tryEval (pkgs.python3Packages.callPackage ./${name}/default.nix { });
        in
        if result.success then result.value else null;

      skills = lib.filterAttrs (_: v: v != null) (
        lib.genAttrs skillDirs buildSkill
      );
    in
    {
      # Expose via legacyPackages so `nix run .#skills.browser-cli` works
      legacyPackages.skills = skills;
    };
}
