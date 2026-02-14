{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
    in
    {
      packages.turbomode = pkgs.stdenv.mkDerivation {
        pname = "turbomode";
        version = "0.1.0";

        src = ./.;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp turbomode.py $out/bin/turbomode
          chmod +x $out/bin/turbomode
          wrapProgram $out/bin/turbomode \
            --prefix PATH : ${python}/bin \
            --set PYTHONPATH ${python}/${python.sitePackages}
          runHook postInstall
        '';

        meta = {
          description = "Turbo/rapid-fire mode for gamepad buttons";
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "turbomode";
        };
      };
    };
}
