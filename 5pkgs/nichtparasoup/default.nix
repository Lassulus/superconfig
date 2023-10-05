{ pkgs, ... }:
let
  py = pkgs.python3Packages.python.withPackages (p: [
    p.werkzeug
    p.beautifulsoup4
  ]);
  src = pkgs.fetchFromGitHub {
    owner = "k4cg";
    repo = "nichtparasoup";
    rev = "c6dcd0d";
    sha256 = "10xy20bjdnd5bjv2hf6v5y5wi0mc9555awxkjqf57rk6ngc5w6ss";
  };
in pkgs.writeDashBin "nichtparasoup" ''
  ${py}/bin/python ${src}/nichtparasoup.py "$@"
''
