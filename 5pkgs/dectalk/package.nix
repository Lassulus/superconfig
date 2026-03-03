{
  lib,
  stdenv,
  fetchFromGitHub,
  autoconf,
  automake,
  pkg-config,
  libpulseaudio,
  alsa-lib,
}:

stdenv.mkDerivation {
  pname = "dectalk";
  version = "0-unstable-2025-10-27";

  src = fetchFromGitHub {
    owner = "dectalk";
    repo = "dectalk";
    rev = "c3c1e4ae4117f951d8d7f9ef2848408ec79047fd";
    hash = "sha256-28d8/LLxtkfjBLRz8jH6xGf16koxMZqm2h67bAey4qg=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
  ];

  buildInputs = [
    libpulseaudio
    alsa-lib
  ];

  postPatch = ''
    # Replace git version detection with static version since .git is not available
    sed -i 's/m4_esyscmd_s(echo $(git describe --always)$(git status --porcelain | awk .*))/c3c1e4a/' src/configure.ac
  '';

  configurePhase = ''
    runHook preConfigure
    cd src
    ./autogen.sh
    ./configure --prefix=$out
    cd ..
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    make -C src -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/dic

    # Libraries
    cp dist/lib/*.so $out/lib/

    # Main binaries
    for bin in say dtmemory aclock; do
      if [ -f "dist/$bin" ]; then
        cp "dist/$bin" $out/bin/
      fi
    done

    # Tools
    if [ -d dist/tools ]; then
      cp dist/tools/* $out/bin/
    fi

    # Dictionaries
    cp dist/dic/* $out/dic/

    # DECtalk config — must be at $out/DECtalk.conf (compiled-in DECTALK_INSTALL_PREFIX)
    cp dist/DECtalk.conf $out/DECtalk.conf

    runHook postInstall
  '';

  meta = {
    description = "Modern builds of the DECtalk text-to-speech engine";
    homepage = "https://github.com/dectalk/dectalk";
    # license = lib.licenses.unfree;
    license = lib.licenses.free;
    platforms = lib.platforms.linux;
    mainProgram = "say";
  };
}
