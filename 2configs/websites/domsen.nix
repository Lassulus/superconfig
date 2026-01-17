{
  lib,
  pkgs,
  ...
}:

let
  inherit (import ./util.nix { inherit lib pkgs; })
    servePage
    ;
in
{
  imports = [
    ./default.nix
    (servePage [
      "illustra.de"
      "www.illustra.de"
    ])
  ];
}
