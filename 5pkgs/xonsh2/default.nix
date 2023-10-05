{ lib, stdenv
, fetchFromGitHub
, python39Packages
, glibcLocales
, coreutils
, git
, extraInputs ? []
}: let

  python3Packages = python39Packages;

in python3Packages.buildPythonApplication rec {
  pname = "xonsh2";
  version = "master";

  # fetch from github because the pypi package ships incomplete tests
  src = fetchFromGitHub {
    owner = "anki-code";
    repo = "xonsh2";
    rev = "bd96fcdce9319ab6b90c7d9ac47d2249b61144d0";
    sha256 = "0b632rac8macfp2mmvhh1f34cf1m5qfpjajwnf676qk7jzn79vx6";
  };

  LC_ALL = "en_US.UTF-8";

  postPatch = ''
    sed -ie 's|/usr/bin/env|${coreutils}/bin/env|' scripts/xon.sh
    find scripts -name 'xonsh*' -exec sed -i -e "s|env -S|env|" {} \;
    find -name "*.xsh" | xargs sed -ie 's|/usr/bin/env|${coreutils}/bin/env|'
    patchShebangs .
  '';

  doCheck = false;

  checkPhase = ''
    HOME=$TMPDIR pytest -k 'not test_repath_backslash and not test_os and not test_man_completion and not test_builtins and not test_main and not test_ptk_highlight and not test_pyghooks'
    HOME=$TMPDIR pytest -k 'test_builtins or test_main' --reruns 5
    HOME=$TMPDIR pytest -k 'test_ptk_highlight'
  '';

  checkInputs = [ python3Packages.pytest python3Packages.pytest-rerunfailures glibcLocales git ];

  propagatedBuildInputs = with python3Packages; [ ply prompt_toolkit pygments ] ++ extraInputs;

  meta = with lib; {
    description = "A Python-ish, BASHwards-compatible shell";
    homepage = "https://xon.sh/";
    # changelog = "https://github.com/xonsh/xonsh/releases/tag/${version}";
    license = licenses.bsd3;
    platforms = platforms.all;
  };

  passthru = {
    shellPath = "/bin/xonsh2";
  };
}
