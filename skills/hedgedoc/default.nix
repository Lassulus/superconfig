{
  python,
  makeWrapper,
  curl,
  lib,
  stdenv,
  ...
}:

let
  pythonWithDeps = python.withPackages (ps: [ ps.websocket-client ]);
in
stdenv.mkDerivation {
  pname = "hedgedoc-skill";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    curl
    pythonWithDeps
  ];

  installPhase = ''
    mkdir -p $out/bin $out/share/hedgedoc
    cp pad-edit.py $out/share/hedgedoc/pad-edit.py
    chmod +x $out/share/hedgedoc/pad-edit.py
    cp pad.sh $out/share/hedgedoc/pad.sh
    chmod +x $out/share/hedgedoc/pad.sh
    cp SKILL.md $out/share/hedgedoc/SKILL.md

    wrapProgram $out/share/hedgedoc/pad-edit.py \
      --prefix PATH : ${lib.makeBinPath [ pythonWithDeps ]}

    wrapProgram $out/share/hedgedoc/pad.sh \
      --prefix PATH : ${lib.makeBinPath [ curl ]} \
      --set SKILL_DIR $out/share/hedgedoc

    ln -s $out/share/hedgedoc/pad.sh $out/bin/pad.sh
  '';

  meta = {
    description = "Manage HedgeDoc pads - create, read, edit collaborative markdown documents";
    mainProgram = "pad.sh";
  };
}
