# Shared builder for Haunted PS1 demo disc games
{
  lib,
  stdenv,
  requireFile,
  unzip,
  makeWrapper,
  umu-launcher,
  makeDesktopItem,
  copyDesktopItems,
}:

{
  pname,
  version ? "1.0",
  zipName,
  sha256,
  exeName,
  downloadUrl,
  downloadName,
  desktopName,
  description,
}:

let
  src = requireFile {
    name = zipName;
    inherit sha256;
    message = ''
      To use this package, you need to download ${desktopName}.

      1. Go to ${downloadUrl}
      2. Create a free itch.io account or log in
      3. Click the "Download" button for "${downloadName}"
      4. Once downloaded, add it to the Nix store:

         nix-store --add-fixed sha256 ~/Downloads/${zipName}

      Then try building again.
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    inherit desktopName;
    comment = description;
    exec = pname;
    icon = pname;
    categories = [ "Game" ];
  };

in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    unzip
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [ desktopItem ];

  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Install all game files
    mkdir -p "$out/share/${pname}"
    cp -r * "$out/share/${pname}/"

    # Create wrapper script using umu-run (Proton launcher)
    mkdir -p "$out/bin"
    cat > "$out/bin/${pname}" <<WRAPPER
#!/bin/sh
export WINEPREFIX="\''${WINEPREFIX:-\$HOME/.local/share/${pname}/prefix}"
export GAMEID="${pname}"
export PROTONPATH="GE-Proton"
exec ${umu-launcher}/bin/umu-run "\$out/share/${pname}/${exeName}" "\$@"
WRAPPER
    substituteInPlace "$out/bin/${pname}" --replace-fail '$out' "$out"
    chmod +x "$out/bin/${pname}"

    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = downloadUrl;
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
