{ fetchgit, stdenv, zip }:

stdenv.mkDerivation rec {
  name = "vimperator";
  id = "vimperator@mozdev.org";

  src = fetchgit {
    url = "https://github.com/vimperator/vimperator-labs.git";
    rev = "ba7d8e72516fdc22246748c8183d7bc90f6fb073";
    sha256 = "0drz67qm5hxxzw699rswlpjkg4p2lfipx119pk1nyixrqblcsvq2";
  };

  buildInputs = [ zip ];

  installPhase = ''
    mkdir -p $out/
    cp downloads/vimperator*.xpi $out/${id}.xpi
  '';
}
