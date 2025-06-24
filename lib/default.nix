{ lib, ... }:
let
  # Pure library functions that don't need pkgs
  superlib = {
    halalify = import ./halalify.nix { inherit lib; };
  };
in
superlib
