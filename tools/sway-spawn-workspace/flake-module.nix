{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3;
    in
    {
      packages.sway-spawn-workspace = pkgs.stdenv.mkDerivation {
        pname = "sway-spawn-workspace";
        version = "0.1.0";
        src = ./.;
        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.ruff
          python.pkgs.mypy
        ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ruff check daemon.py
          ruff format --check daemon.py
          mypy --strict daemon.py
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp daemon.py $out/bin/sway-spawn-workspace
          chmod +x $out/bin/sway-spawn-workspace
          wrapProgram $out/bin/sway-spawn-workspace \
            --prefix PATH : ${python}/bin:${pkgs.sway}/bin:${pkgs.tmux}/bin
          runHook postInstall
        '';
        meta.mainProgram = "sway-spawn-workspace";
      };
    };
}
