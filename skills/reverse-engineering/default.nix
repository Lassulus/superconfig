{ stdenv, ... }:

stdenv.mkDerivation {
  pname = "reverse-engineering-skill";
  version = "0.1.0";
  src = ./.;

  installPhase = ''
    mkdir -p $out/share/reverse-engineering
    cp SKILL.md $out/share/reverse-engineering/SKILL.md
  '';

  meta = {
    description = "Reverse engineer and debug binaries using Ghidra and GDB";
  };
}
