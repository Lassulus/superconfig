{ pkgs, ... }:
let
  pp = pkgs.python35Packages;
in pp.buildPythonPackage rec {
  name = "xml2json-${version}";
  version = "22ffcd";
  propagatedBuildInputs = [
    pp.simplejson
  ];
  src = pkgs.fetchFromGitHub {
    owner = "hay";
    repo = "xml2json";
    rev = "${version}";
    sha256 = "1snjd6q6bk517350gdrl8kkphkra0iaz56i583h2q57ab09r29vc";
  };
  doCheck = false;
}
