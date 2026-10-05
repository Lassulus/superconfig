{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
}:

# Calino: a static, local-first CalDAV web client. Accounts, settings and the
# event cache live in the browser; there is no backend. The CalDAV server has
# to allow the origin Calino is served from via CORS.
stdenv.mkDerivation (finalAttrs: {
  pname = "calino";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "Ivan-Malinovski";
    repo = "calino";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DaT4vJB1/zTPwWnoDvHHQT7XlhmctHVLMIoedgs/1B4=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-7V/Ej1xiVu8b4sLiADulSZtZ0kb3nRzTqqYfIGTPxGc=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';

  meta = {
    description = "Local-first CalDAV calendar web client (static files)";
    homepage = "https://github.com/Ivan-Malinovski/calino";
    changelog = "https://github.com/Ivan-Malinovski/calino/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
