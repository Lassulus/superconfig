{
  python3Packages,
  lib,
}:
python3Packages.buildPythonApplication {
  pname = "archiver-bot";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    matrix-nio
    aiohttp
  ];

  meta = {
    description = "Matrix bot that requests movies/shows via Jellyseerr when IMDb links are posted";
    mainProgram = "archiver-bot";
    platforms = lib.platforms.all;
  };
}
