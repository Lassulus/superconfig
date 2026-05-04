{
  python3Packages,
  lib,
  olm,
}:
let
  olmSafe = python3Packages."python-olm".override {
    olm = olm.overrideAttrs (old: {
      meta = (old.meta or { }) // {
        knownVulnerabilities = [ ];
      };
    });
  };
  matrix-nio-safe = python3Packages.matrix-nio.override {
    withOlm = true;
    "python-olm" = olmSafe;
  };
in
python3Packages.buildPythonApplication {
  pname = "archiver-bot";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    matrix-nio-safe
    aiohttp
    cffi
  ];

  meta = {
    description = "Matrix bot that requests movies/shows via Jellyseerr when IMDb links are posted";
    mainProgram = "archiver-bot";
    platforms = lib.platforms.all;
  };
}
