{
  lib,
  buildGoModule,
  fetchFromGitea,
  go_1_27,
}:

# go.mod requires go 1.27; nixpkgs' default go is still 1.26.
(buildGoModule.override { go = go_1_27; }) (
  finalAttrs:
  let
    rev = "52118a9e2475bd3f8c4d62e3032eaf821a9a239d";
  in
  {
    pname = "parley";
    version = "0.5.0-unstable-2026-09-27";

    src = fetchFromGitea {
      domain = "git.mills.io";
      owner = "prologic";
      repo = "parley";
      inherit rev;
      hash = "sha256-bFeX5Nd8IvtY6Di+YUCZtclGkV2bTdIxTWpivCtRqLM=";
    };

    vendorHash = "sha256-siSavE8i/Rh6LfI+HXhyKsPrbfyncJCcEYJsA4KZ378=";

    # modernc.org/sqlite is pure Go; upstream builds static binaries.
    env.CGO_ENABLED = 0;

    # The generated templ components and the compiled stylesheet are
    # committed upstream, so neither templ nor tailwind is needed here.
    subPackages = [
      "cmd/parleyd"
      "cmd/parleyctl"
    ];

    ldflags = [
      "-s"
      "-w"
      "-X main.Version=${finalAttrs.version}"
      "-X main.Commit=${builtins.substring 0 7 rev}"
    ];

    meta = {
      description = "Federated, decentralised chat that speaks plain IRC";
      homepage = "https://git.mills.io/prologic/parley";
      license = lib.licenses.mit;
      mainProgram = "parleyd";
      platforms = lib.platforms.unix;
    };
  }
)
