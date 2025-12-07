{
  lib,
  mkYarnPackage,
  fetchFromGitHub,
  fetchYarnDeps,
  makeWrapper,
  nodejs,
}:

mkYarnPackage rec {
  pname = "happy-coder";
  version = "0.11.2";

  src = fetchFromGitHub {
    owner = "slopus";
    repo = "happy-cli";
    rev = "v${version}";
    hash = "sha256-WKzbpxHqE3Dxqy/PDj51tM9+Wl2Pallfrc5UU2MxNn8=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-3/qcbCJ+Iwc+9zPCHKsCv05QZHPUp0it+QR3z7m+ssw=";
  };

  packageJSON = "${src}/package.json";

  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ''
    runHook preBuild
    yarn --offline build
    runHook postBuild
  '';

  # Wrap binaries to include node in PATH (needed for daemon subprocess spawning)
  postInstall = ''
    for bin in $out/bin/*; do
      wrapProgram "$bin" --prefix PATH : ${lib.makeBinPath [ nodejs ]}
    done
  '';

  distPhase = "true";

  meta = {
    description = "Mobile and Web client for Claude Code and Codex";
    homepage = "https://github.com/slopus/happy-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "happy";
  };
}
