{ ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      python = pkgs.python3.withPackages (_ps: [
        self'.packages.vosk
      ]);
    in
    {
      packages.stt = pkgs.stdenv.mkDerivation {
        pname = "stt";
        version = "0.4.0";
        src = ./.;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp stt.py $out/bin/stt
          chmod +x $out/bin/stt
          wrapProgram $out/bin/stt \
            --prefix PATH : ${python}/bin \
            --set PYTHONPATH ${python}/${python.sitePackages}
          runHook postInstall
        '';
        meta.mainProgram = "stt";
      };
    };
}
