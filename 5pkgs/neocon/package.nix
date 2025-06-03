{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (_finalAttrs: {
  pname = "neocon";
  version = "unstable-2023-06-30";

  src = fetchFromGitHub {
    owner = "sysprog21";
    repo = "neocon";
    rev = "879615f518b9aca23e8d148242d319c103620e0e";
    hash = "sha256-X8yVdYhUKPnNV8RAXp9JIy5IZBnWB9fzpEV+QH0fND4=";
  };

  doCheck = true;

  installPhase = ''
    mkdir -p $out/bin
    cp neocon $out/bin
  '';
})
