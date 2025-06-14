{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.jellyseekrr = pkgs.writeShellApplication {
        name = "jellyseekrr";
        runtimeInputs = with pkgs; [
          self.packages.${pkgs.system}.menu
          self.packages.${pkgs.system}.pass
          curl
          jq
        ];
        text = builtins.readFile ./jellyseekrr.sh;
      };
    };
}