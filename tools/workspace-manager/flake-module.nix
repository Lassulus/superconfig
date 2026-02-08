{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3;
    in
    {
      packages.workspace-manager = pkgs.writeShellApplication {
        name = "workspace-manager";
        runtimeInputs = [
          pkgs.socat
          pkgs.jq
        ];
        text = builtins.readFile ./workspace-manager.sh;
      };

      packages.workspace-manager-daemon = pkgs.stdenv.mkDerivation {
        pname = "workspace-manager-daemon";
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
          cp daemon.py $out/bin/workspace-manager-daemon
          chmod +x $out/bin/workspace-manager-daemon
          wrapProgram $out/bin/workspace-manager-daemon \
            --prefix PATH : ${python}/bin:${pkgs.sway}/bin
          runHook postInstall
        '';
        meta.mainProgram = "workspace-manager-daemon";
      };
    };
}
