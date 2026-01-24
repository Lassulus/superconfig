{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      mpv = self.packages.${system}.mpv;
      extension = pkgs.writeText "custom-mpv" ''
        MPV_CMD="${mpv}/bin/mpv"
      '';
    in
    {
      packages.yt-x = pkgs.writeShellScriptBin "yt-x" ''
        exec nix run \
          --override-input nixpkgs path:${self.inputs.nixpkgs} \
          github:Lassulus/yt-x/allow-full-path-extensions -- \
          -x ${extension} "$@"
      '';
    };
}
