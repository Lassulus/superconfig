{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.whatsong =
        (pkgs.writeShellApplication {
          name = "whatsong";
          runtimeInputs = [
            pkgs.sox
            pkgs.songrec
            pkgs.jq
            pkgs.yt-dlp
          ];
          text = builtins.readFile ./whatsong.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
