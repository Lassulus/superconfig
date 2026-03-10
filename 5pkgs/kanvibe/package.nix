{
  lib,
  stdenv,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  tmux,
  git,
  openssh,
  fetchFromGitHub,
}:

let
  src = fetchFromGitHub {
    owner = "Lassulus";
    repo = "kanvibe";
    rev = "6887b163b7ab36c2f4f41bd02bf6c648ebe85840";
    hash = "sha256-FTszbYyYlTqDJxHVRPV9VMu9i+gRrdTq1du1nbzHjdA=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "kanvibe";
  version = "0.1.0";

  inherit src;

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    pname = "kanvibe";
    inherit (finalAttrs) version src;
    pnpm = pnpm_10;
    hash = "sha256-POorUzaa5JFmQygDNlGY7G4XoZOf7iW6UIyqgmF05b0=";
    fetcherVersion = 2;
  };

  buildPhase = ''
        runHook preBuild

        export NEXT_TELEMETRY_DISABLED=1

        # Set default locale to English
    substituteInPlace src/i18n/routing.ts \
      --replace-fail 'defaultLocale: "ko"' 'defaultLocale: "en"'

    # Patch out Google Fonts (no network in sandbox)
        substituteInPlace src/app/\[locale\]/layout.tsx \
          --replace-fail 'import { Inter } from "next/font/google";' "" \
          --replace-fail 'const inter = Inter({
      variable: "--font-inter",
      subsets: ["latin"],
    });' 'const inter = { variable: "" };'

    pnpm build

    # Replace @/ path aliases with absolute paths for runtime tsx resolution
    # (Next.js require-hook interferes with tsx's tsconfig paths resolution)
    find . -name '*.ts' -not -path './node_modules/*' -not -path './.next/*' \
      -exec sed -i "s|from \"@/|from \"$out/lib/kanvibe/src/|g" {} +
    find . -name '*.ts' -not -path './node_modules/*' -not -path './.next/*' \
      -exec sed -i "s|from '@/|from '$out/lib/kanvibe/src/|g" {} +

        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/kanvibe

    # Copy the built Next.js app
    cp -r .next $out/lib/kanvibe/.next

    # Copy runtime files
    cp boot.js $out/lib/kanvibe/
    cp server.ts $out/lib/kanvibe/
    cp next.config.ts $out/lib/kanvibe/
    cp package.json $out/lib/kanvibe/
    cp tsconfig.json $out/lib/kanvibe/
    cp -r src $out/lib/kanvibe/src
    cp -r messages $out/lib/kanvibe/messages
    cp -r public $out/lib/kanvibe/public 2>/dev/null || true

    # node_modules needed at runtime (tsx, typeorm, node-pty, etc.)
    cp -r node_modules $out/lib/kanvibe/node_modules

    mkdir -p $out/bin
    # Patch boot.js to chdir to package directory so tsx finds tsconfig.json
    substituteInPlace $out/lib/kanvibe/boot.js \
      --replace-fail 'require("tsx/cjs");' \
        'process.chdir(__dirname); require("tsx/cjs");'

    makeWrapper ${nodejs}/bin/node $out/bin/kanvibe \
      --add-flags "$out/lib/kanvibe/boot.js" \
      --set NODE_ENV production \
      --prefix PATH : ${
        lib.makeBinPath [
          tmux
          git
          openssh
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "AI Agent Task Management Kanban Board";
    homepage = "https://github.com/Lassulus/kanvibe";
    license = lib.licenses.agpl3Only;
    mainProgram = "kanvibe";
    platforms = lib.platforms.unix;
  };
})
