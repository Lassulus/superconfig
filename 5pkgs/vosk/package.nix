{
  lib,
  python3Packages,
  fetchurl,
  stdenv,
}:
let
  version = "0.3.44";

  # Platform-specific wheels
  wheels = {
    "x86_64-linux" = {
      url = "https://files.pythonhosted.org/packages/py3/v/vosk/vosk-${version}-py3-none-manylinux_2_12_x86_64.manylinux2010_x86_64.whl";
      hash = "sha256-JlLvITxMeAfcQK8eeqV43Mz8TcQZKCKia8RalZG8v3Y=";
    };
    "aarch64-linux" = {
      url = "https://files.pythonhosted.org/packages/py3/v/vosk/vosk-${version}-py3-none-manylinux2014_aarch64.whl";
      hash = "sha256-mZW3+lQ0sTS0vQmJfiSQ28VhFcKtKUPAMGIeEMcDezQ=";
    };
    "x86_64-darwin" = {
      url = "https://files.pythonhosted.org/packages/py3/v/vosk/vosk-${version}-py3-none-macosx_10_6_universal2.whl";
      hash = "sha256-Ap0LPWpc/4dMV1uKWBSkzM+zdgjP9S6EbAKoxnqIKAE=";
    };
    "aarch64-darwin" = {
      url = "https://files.pythonhosted.org/packages/py3/v/vosk/vosk-${version}-py3-none-macosx_10_6_universal2.whl";
      hash = "sha256-Ap0LPWpc/4dMV1uKWBSkzM+zdgjP9S6EbAKoxnqIKAE=";
    };
  };

  wheel =
    wheels.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
python3Packages.buildPythonPackage {
  pname = "vosk";
  inherit version;
  format = "wheel";

  src = fetchurl {
    inherit (wheel) url hash;
  };

  dependencies = with python3Packages; [
    cffi
    requests
    tqdm
    srt
    websockets
  ];

  # Skip tests as they require audio files and models
  doCheck = false;

  pythonImportsCheck = [ "vosk" ];

  meta = {
    description = "Offline speech recognition API based on Kaldi and Vosk";
    homepage = "https://alphacephei.com/vosk/";
    license = lib.licenses.asl20;
    platforms = lib.attrNames wheels;
  };
}
