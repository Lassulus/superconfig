{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (ps: with ps; [
    mcp
  ]);
in
pkgs.writeShellApplication {
  name = "git-mcp";
  runtimeInputs = with pkgs; [
    git
    python
  ];
  text = ''
    ${python}/bin/python ${./git-mcp.py} "$@"
  '';
}
