{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      memhack-repl = pkgs.writeShellApplication {
        name = "memhack-repl";
        runtimeInputs = [
          pkgs.python3
        ];
        text = ''exec python3 ${./memhack-repl.py} "$@"'';
      };
    in
    {
      packages.memhack = pkgs.writeShellApplication {
        name = "memhack";
        runtimeInputs = [
          pkgs.procps
          pkgs.fzf
          memhack-repl
        ];
        text = builtins.readFile ./memhack.sh;
      };
    };
}
