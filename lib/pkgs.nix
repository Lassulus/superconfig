# Library functions that require pkgs
{ lib, pkgs, ... }:
let
  superlib = import ./default.nix { inherit lib; };
in
{
  # Import functions that need pkgs
  makeWrapper = (import ./make-wrapper.nix { inherit lib superlib pkgs; }).makeWrapper;
}