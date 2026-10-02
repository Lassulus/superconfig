{
  lib,
  applyPatches,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
}:

let
  version = "0-unstable-2026-10-01";

  # self-host.patch (AGPL-3.0 §13: this directory is the corresponding source
  # linked from the footer and the landing page):
  # - strips Google Tag Manager, Publift/Primis ads, the paywall and the
  #   landing page's YouTube/Vimeo embeds and GitHub star button
  # - replaces the Google/Outlook/email-OTP sign-in page with GitHub OAuth
  #   (GET /api/auth/github, GITHUB_CLIENT_ID/GITHUB_CLIENT_SECRET)
  # - "Schedule" offers a .ics download next to Google Calendar/Outlook, and
  #   scheduled-event links point at this instance instead of timeful.app
  # - makes the listen address configurable via LISTEN_ADDR (upstream
  #   hardcodes ":3002" on all interfaces)
  src = applyPatches {
    src = fetchFromGitHub {
      owner = "schej-it";
      repo = "timeful.app";
      rev = "23b7e7ead1d279ea5d8f431199a230c2dfbe0c1a";
      hash = "sha256-Yp2dkz4+QZ9pqZXOM4srZsCiu/TGLQXGNZtsRd5Dx+U=";
    };
    patches = [ ./self-host.patch ];
  };

  frontend = buildNpmPackage {
    pname = "timeful-frontend";
    inherit version;
    src = "${src}/frontend";

    npmDepsHash = "sha256-eHitoSJUPX2mhlOgGrECCUp0zhKFxgsfxkY7+BmeHak=";

    # No PostHog key and no Google/Microsoft OAuth client baked in; sign-in
    # goes through the server-side GitHub flow instead.
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "timeful";
  inherit version src;

  modRoot = "server";
  subPackages = [ "." ];
  vendorHash = "sha256-dl9JURh6pCB7P+jAWcjlPZwmkKPqV7EaOJZSwJYwcFQ=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    mv $out/bin/server $out/bin/timeful
    wrapProgram $out/bin/timeful --set-default FRONTEND_DIST ${frontend}
  '';

  passthru = { inherit frontend; };

  meta = {
    description = "Availability poll to find the best time for a group to meet (formerly Schej)";
    homepage = "https://github.com/schej-it/timeful.app";
    license = lib.licenses.agpl3Only;
    mainProgram = "timeful";
    platforms = lib.platforms.linux;
  };
}
