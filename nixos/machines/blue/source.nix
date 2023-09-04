{ lib, pkgs, test, ... }:
if test then {} else {
  nixpkgs = lib.mkIf (! test) (lib.mkForce {
    file = {
      path = toString (pkgs.fetchFromGitHub {
        owner = "nixos";
        repo = "nixpkgs";
        rev = (lib.importJSON ../../../krebs/nixpkgs.json).rev;
        sha256 = (lib.importJSON ../../../krebs/nixpkgs.json).sha256;
      });
      useChecksum = true;
    };
  });
  nixpkgs-unstable = lib.mkForce {
    file.path = "/var/empty";
  };
}
