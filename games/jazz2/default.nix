{
  fetchurl,
  jazz2,
  lib,
  runCommandLocal,
  stdenvNoCC,
  unzip,
  writeShellScript,
}:

let
  gameData = fetchurl {
    url = "https://archive.org/download/jazz-jackrabbit-2-1.24-the-secret-files-plus/Jazz%20Jackrabbit%202%201.24%20The%20Secret%20Files%20Plus.zip";
    hash = "sha256-ceeXiGUy5QDq1HQPo5gpyQe2odAK1F5frofBXegeXi8=";
    name = "jazz-jackrabbit-2-tsf.zip";
  };

  sourceData = runCommandLocal "jazz2-source-data" {
    nativeBuildInputs = [ unzip ];
  } ''
    mkdir -p "$out/Jazz² Resurrection/Source"
    unzip -j -o ${gameData} -d "$out/Jazz² Resurrection/Source/"
  '';

  wrapper = writeShellScript "jazz2" ''
    datadir="''${XDG_DATA_HOME:-$HOME/.local/share}/Jazz² Resurrection"
    if [ ! -e "$datadir/Source/Anims.j2a" ]; then
      mkdir -p "$datadir"
      rm -rf "$datadir/Source"
      ln -sfn "${sourceData}/Jazz² Resurrection/Source" "$datadir/Source"
    fi
    exec ${lib.getExe jazz2} "$@"
  '';
in

stdenvNoCC.mkDerivation {
  pname = "jazz2-with-gamedata";
  inherit (jazz2) version;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    ln -s ${wrapper} $out/bin/jazz2
  '';

  meta = jazz2.meta // {
    description = "Jazz Jackrabbit 2 (Jazz² Resurrection with game data)";
  };
}
