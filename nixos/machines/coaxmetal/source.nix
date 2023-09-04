{ lib, pkgs, test, ... }: let
  npkgs = lib.importJSON ../../../krebs/nixpkgs-unstable.json;
in {
  nixpkgs = (if test then lib.mkForce ({ derivation = let
    rev = npkgs.rev;
    sha256 = npkgs.sha256;
  in ''
    with import (builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      sha256 = "${sha256}";
    }) {};
    pkgs.fetchFromGitHub {
      owner = "nixos";
      repo = "nixpkgs";
      rev = "${rev}";
      sha256 = "${sha256}";
    }
  ''; }) else {
    git.ref = lib.mkForce npkgs.rev;
  });
}
