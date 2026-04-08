{ stdenv, ... }:

stdenv.mkDerivation {
  pname = "websearch-skill";
  version = "0.1.0";
  src = ./.;

  installPhase = ''
    mkdir -p $out/share/websearch
    cp SKILL.md $out/share/websearch/SKILL.md
  '';

  meta = {
    description = "Search the web via Kagi and fetch page contents";
  };
}
