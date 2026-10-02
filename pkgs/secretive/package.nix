{
  lib,
  stdenvNoCC,
  fetchzip,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "secretive";
  version = "2.4.1";

  src = fetchzip {
    url = "https://github.com/maxgoedjen/secretive/releases/download/v${version}/Secretive.zip";
    hash = "sha256-JzG7AWpvo/ivtb5JARNCYIQiLuqFYe6Peg2T444Qv0M=";
    stripRoot = false;
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R Secretive.app $out/Applications/

    runHook postInstall
  '';

  meta = {
    description = "Store SSH keys in the Secure Enclave";
    homepage = "https://github.com/maxgoedjen/secretive";
    changelog = "https://github.com/maxgoedjen/secretive/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.darwin;
    mainProgram = "Secretive";
  };
}
