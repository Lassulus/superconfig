{ fetchgit, stdenv, bash, zip }:

stdenv.mkDerivation rec {
  name = "noscript";
  id = "{73a6fe31-595d-460b-a920-fcc0f8843232}";

  src = fetchgit {
    url = "https://github.com/avian2/noscript";
    rev = "c900a079793868bb080ab1e23522d29dc121b4c6";
    sha256 = "1y06gh5a622yrsx0h7v92qnvdi97i54ln09zc1lvk8x430z5bdly";
  };

  buildInputs = [ zip ];

  patchPhase = ''
    substituteInPlace "version.sh" \
    --replace "/bin/bash" "${bash}/bin/bash"
  '';

  buildPhase = ''
    ./makexpi.sh
  '';

  installPhase = ''
    mkdir -p $out/
    cp *.xpi $out/${id}.xpi
  '';
}
