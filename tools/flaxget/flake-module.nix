{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.flaxget = pkgs.writeShellApplication {
        name = "flaxget";
        runtimeInputs = [
          pkgs.curl
          pkgs.fzf
          pkgs.coreutils
          pkgs.aria2
        ];
        text = builtins.readFile ./flaxget.sh;
      };
    };
}
