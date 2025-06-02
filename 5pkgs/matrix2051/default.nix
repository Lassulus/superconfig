{
  lib,
  stdenv,
  fetchFromGitHub,
  beam,
  openssl,
  zlib,
}:

let
  pname = "matrix2051";
  version = "0.1.0";

  beamPackages = beam.packagesWith beam.interpreters.erlang;

  src = fetchFromGitHub {
    owner = "progval";
    repo = "matrix2051";
    rev = "47e46ac6c22b49e16d90be945120dbfb9ad387cf";
    hash = "sha256-O0UPsYLCUsTCt4g2KskBkCIOxvpqo4GejCNkc9NT1K0=";
  };

  mixDeps = import ./mix.nix { inherit lib beamPackages; };

in
beamPackages.buildMix {
  name = "${pname}-${version}";
  inherit version src;

  patches = [ ./add-mix-lock.patch ];

  buildInputs = [
    openssl
    zlib
  ];

  beamDeps = with mixDeps; [
    certifi
    hackney
    httpoison
    idna
    jason
    metrics
    mimerl
    mochiweb
    mox
    parse_trans
    ssl_verify_fun
    unicode_util_compat
  ];

  postPatch = ''
    # Replace HTTPoison structs with fully qualified module references
    substituteInPlace lib/matrix/raw_client.ex \
      --replace-fail "%HTTPoison.Response{" "%{__struct__: HTTPoison.Response, " \
      --replace-fail "%HTTPoison.Error{" "%{__struct__: HTTPoison.Error, "

    substituteInPlace lib/matrix_client/client.ex \
      --replace-fail "%HTTPoison.Response{" "%{__struct__: HTTPoison.Response, " \
      --replace-fail "%HTTPoison.Error{" "%{__struct__: HTTPoison.Error, "
  '';

  postInstall = ''
    # Create wrapper script for easier execution
    mkdir -p $out/bin
    cat > $out/bin/matrix2051 << 'EOF'
#!/usr/bin/env bash
exec $out/bin/matrix2051 start "$@"
EOF
    chmod +x $out/bin/matrix2051
  '';

  meta = with lib; {
    description = "A Matrix gateway for IRC: connect to Matrix from your favorite IRC client";
    homepage = "https://github.com/progval/matrix2051";
    license = licenses.agpl3Plus;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}