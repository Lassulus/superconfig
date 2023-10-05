{ lib, pkgs, test, ... }: let
  npkgs = lib.importJSON ../../../krebs/nixpkgs-unstable.json;
in if test then {} else {
  nixpkgs.git.ref = lib.mkForce npkgs.rev;
  nixpkgs-unstable = lib.mkForce { file = "/var/empty"; };
}
