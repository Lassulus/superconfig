{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "levenshtein-merge";
  version = "0.1.0";

  src = ./.;

  buildPhase = ''
    $CC -O2 -o levenshtein-merge levenshtein.c
  '';

  installPhase = ''
    install -Dm755 levenshtein-merge $out/bin/levenshtein-merge
  '';

  meta = {
    description = "Fuzzy line-level file merge using Levenshtein distance";
    license = lib.licenses.mit;
    mainProgram = "levenshtein-merge";
    platforms = lib.platforms.all;
  };
}
