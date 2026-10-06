# reaktor2 IRC bot, taken from stockholm's krebs/5pkgs/haskell (cc283503),
# which is not part of stockholm's packages output. blessings is not in
# nixpkgs' haskellPackages, so it comes along.
{ haskellPackages }:
let
  hp = haskellPackages.override {
    overrides = self: _: {
      blessings = self.callPackage ./blessings.nix { };
    };
  };
in
hp.callPackage ./reaktor2.nix { }
