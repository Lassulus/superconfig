{
  perSystem =
    { pkgs, ... }:
    {
      packages.yt-dlp = pkgs.writeShellScriptBin "yt-dlp" ''
        args=$@
        nix-shell -p '(yt-dlp.overrideAttrs (_: {
          src = builtins.fetchTree "github:yt-dlp/yt-dlp";
          patches = [];
          postPatch = "python devscripts/update-version.py 0.99";
        }))' -p deno --run "yt-dlp $args"
      '';
    };
}
