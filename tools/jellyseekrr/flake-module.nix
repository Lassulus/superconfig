{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.jellyseekrr =
        (pkgs.writeShellApplication {
          name = "jellyseekrr";
          runtimeInputs = with pkgs; [
            self.packages.${pkgs.system}.menu
            rbw
            curl
            jq
          ];
          text = builtins.readFile ./jellyseekrr.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
