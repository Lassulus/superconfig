{ fetchgit, stdenv, bash, python, zip }:

stdenv.mkDerivation rec {
  name = "ublock";
  id = "{2b10c1c8-a11f-4bad-fe9c-1c11e82cac42}";

  src = fetchgit {
    url = "https://github.com/chrisaljoudi/uBlock";
    rev = "a70a50052a7914cbf86d46a725812b98434d8c70";
    sha256 = "1qfzy79f8x01i33x0m95k833z1jgxjwb8wvlr6fj6id1kxfvzh77";
  };

  buildInputs = [
    zip
    python
  ];

  patchPhase = ''
    substituteInPlace "tools/make-firefox.sh" \
    --replace "/bin/bash" "${bash}/bin/bash"
  '';

  buildPhase = ''
    tools/make-firefox.sh all
  '';

  installPhase = ''
    mkdir -p $out/
    cp dist/build/uBlock.firefox.xpi $out/${id}.xpi
  '';
}
