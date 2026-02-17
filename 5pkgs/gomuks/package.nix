{
  lib,
  fetchFromGitHub,
  fetchNpmDeps,
  buildGoModule,
  nodejs,
  npmHooks,
}:

# gomuks TUI with E2EE via pure-Go goolm (no insecure libolm needed)
# Built from the new gomuks codebase which includes cmd/gomuks-terminal
buildGoModule (
  finalAttrs:
  let
    rev = "82abf26775d59c642fa7ea5274cf8631cd6942c6";
  in
  {
    pname = "gomuks";
    version = "0.2601.0";

    proxyVendor = true;
    vendorHash = "sha256-M493helHfjHyJCqHxyaC2wkhtsFNA937crdnfCWj9IQ=";

    src = fetchFromGitHub {
      owner = "gomuks";
      repo = "gomuks";
      hash = "sha256-0AqA1Fl6xIotmF1hYfEm2FEEiSBzBp7RDnaJjTBeTwU=";
      inherit rev;
    };

    nativeBuildInputs = [
      nodejs
      npmHooks.npmConfigHook
    ];

    env = {
      npmRoot = "web";
      npmDeps = fetchNpmDeps {
        src = "${finalAttrs.src}/web";
        hash = "sha256-SUxE4SZOZI+GgLTecRf5rqYRv3koV85eCZ1TFKO4gTI=";
      };
    };

    postPatch = ''
      substituteInPlace ./web/build-wasm.sh \
        --replace-fail 'go.mau.fi/gomuks/version.Tag=$(git describe --exact-match --tags 2>/dev/null)' "go.mau.fi/gomuks/version.Tag=v${finalAttrs.version}" \
        --replace-fail 'go.mau.fi/gomuks/version.Commit=$(git rev-parse HEAD)' "go.mau.fi/gomuks/version.Commit=${rev}"
    '';

    doCheck = false;

    tags = [ "goolm" ];

    ldflags = [
      "-X 'go.mau.fi/gomuks/version.Tag=v${finalAttrs.version}'"
      "-X 'go.mau.fi/gomuks/version.Commit=${rev}'"
    ];

    subPackages = [
      "cmd/gomuks-terminal"
    ];

    preBuild = ''
      CGO_ENABLED=0 go generate ./web
    '';

    postInstall = ''
      mv $out/bin/gomuks-terminal $out/bin/gomuks
    '';

    meta = {
      mainProgram = "gomuks";
      description = "Terminal Matrix client with E2EE via goolm";
      homepage = "https://github.com/tulir/gomuks";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.unix;
    };
  }
)
