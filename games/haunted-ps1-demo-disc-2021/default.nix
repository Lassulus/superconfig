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

let
  pname = "haunted-ps1-demo-disc-2021";
  version = "1.0";

  # Download from: https://hauntedps1.itch.io/demodisc2021
  # You need an itch.io account (free) to download
  # After downloading, add to nix store with:
  #   nix-store --add-fixed sha256 ~/Downloads/demodisc2021-win.zip
  src = requireFile {
    name = "demodisc2021-win.zip";
    sha256 = "0392n5pgilpk0lgwr35w6jl6hq9h800y8lkpb729vjhw4c7ywsmm";
    message = ''
      To use this package, you need to download the Haunted PS1 Demo Disc 2021.

      1. Go to https://hauntedps1.itch.io/demodisc2021
      2. Create a free itch.io account or log in
      3. Click the "Download" button for "Demo Disc 2021 [Windows]" (4.7 GB)
      4. Once downloaded, add it to the Nix store:

         nix-store --add-fixed sha256 ~/Downloads/demodisc2021-win.zip

      Then try building again.
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Haunted PS1 Demo Disc 2021";
    comment = "A collection of PS1-style horror game demos";
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
    cat > "$out/bin/${pname}" <<'WRAPPER'
#!/bin/sh
export WINEPREFIX="''${WINEPREFIX:-$HOME/.local/share/haunted-ps1-demo-disc-2021/prefix}"
export GAMEID="haunted-ps1-demo-disc-2021"
export PROTONPATH="GE-Proton"
exec UMUPATH "$out/share/haunted-ps1-demo-disc-2021/HauntedDemoDisc2021.exe" "$@"
WRAPPER
    substituteInPlace "$out/bin/${pname}" \
      --replace-fail "UMUPATH" "${umu-launcher}/bin/umu-run" \
      --replace-fail '$out' "$out"
    chmod +x "$out/bin/${pname}"

    runHook postInstall
  '';

  meta = {
    description = "A collection of 25 PS1-style horror game demos from the Haunted PS1 community";
    homepage = "https://hauntedps1.itch.io/demodisc2021";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
