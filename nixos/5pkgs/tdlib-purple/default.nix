{ stdenv, pkgs, fetchFromGitHub, cmake, pidgin, libwebp, libtgvoip } :

let

  tdlib = stdenv.mkDerivation rec {
    version = "1.6.0";
    pname = "tdlib";

    src = fetchFromGitHub {
      owner = "tdlib";
      repo = "td";
      rev = "v${version}";
      sha256 = "0zlzpl6fgszg18kwycyyyrnkm255dvc6fkq0b0y32m5wvwwl36cv";
    };

    buildInputs = with pkgs; [ gperf openssl readline zlib ];
    nativeBuildInputs = [ pkgs.cmake ];

  };

in stdenv.mkDerivation rec {
  pname = "tdlib-purple";
  version = "0.7.8";

  src = fetchFromGitHub {
    owner = "ars3niy";
    repo = pname;
    rev = "v${version}";
    sha256 = "17g54mcxsidcx37l6m4p8i06ln1hvq3347dhdl9xkkn7pqpwvv1c";
  };

  cmakeFlags = [
    "-Dtgvoip_INCLUDE_DIRS=${libtgvoip.dev}/include/tgvoip"
  ];

  nativeBuildInputs = [ cmake ];
  buildInputs = [ pidgin tdlib libwebp libtgvoip ];

  installPhase = ''
    mkdir -p $out/lib/purple-2/
    cp *.so $out/lib/purple-2/
  '';

  meta = with stdenv.lib; {
    homepage = "https://github.com/ars3niy/tdlib-purple";
    description = "New libpurple plugin for Telegram";
    license = licenses.gpl2;
    maintainers = [ maintainers.lassulus ];
    platforms = platforms.linux;
  };
}
