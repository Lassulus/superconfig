{ stdenv, ... }:

stdenv.mkDerivation {
  pname = "tmux-skill";
  version = "0.1.0";
  src = ./.;

  installPhase = ''
    mkdir -p $out/share/tmux
    cp SKILL.md $out/share/tmux/SKILL.md
  '';

  meta = {
    description = "Drive tmux to run long-running commands and capture output";
  };
}
