{ lib, beamPackages, overrides ? (x: y: {}) }:

let
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

  self = packages // (overrides self packages);

  packages = with beamPackages; with self; {
    certifi = buildRebar3 rec {
      name = "certifi";
      version = "2.15.0";

      src = fetchHex {
        pkg = "certifi";
        version = "${version}";
        sha256 = "b147ed22ce71d72eafdad94f055165c1c182f61a2ff49df28bcc71d1d5b94a60";
      };

      beamDeps = [];
    };

    hackney = buildRebar3 rec {
      name = "hackney";
      version = "1.24.1";

      src = fetchHex {
        pkg = "hackney";
        version = "${version}";
        sha256 = "f4a7392a0b53d8bbc3eb855bdcc919cd677358e65b2afd3840b5b3690c4c8a39";
      };

      beamDeps = [ certifi idna metrics mimerl parse_trans ssl_verify_fun unicode_util_compat ];
    };

    httpoison = buildMix rec {
      name = "httpoison";
      version = "1.8.2";

      src = fetchHex {
        pkg = "httpoison";
        version = "${version}";
        sha256 = "2bb350d26972e30c96e2ca74a1aaf8293d61d0742ff17f01e0279fef11599921";
      };

      beamDeps = [ hackney ];
    };

    idna = buildRebar3 rec {
      name = "idna";
      version = "6.1.1";

      src = fetchHex {
        pkg = "idna";
        version = "${version}";
        sha256 = "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea";
      };

      beamDeps = [ unicode_util_compat ];
    };

    jason = buildMix rec {
      name = "jason";
      version = "1.4.4";

      src = fetchHex {
        pkg = "jason";
        version = "${version}";
        sha256 = "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b";
      };

      beamDeps = [];
    };

    metrics = buildRebar3 rec {
      name = "metrics";
      version = "1.0.1";

      src = fetchHex {
        pkg = "metrics";
        version = "${version}";
        sha256 = "69b09adddc4f74a40716ae54d140f93beb0fb8978d8636eaded0c31b6f099f16";
      };

      beamDeps = [];
    };

    mimerl = buildRebar3 rec {
      name = "mimerl";
      version = "1.4.0";

      src = fetchHex {
        pkg = "mimerl";
        version = "${version}";
        sha256 = "13af15f9f68c65884ecca3a3891d50a7b57d82152792f3e19d88650aa126b144";
      };

      beamDeps = [];
    };

    mochiweb = buildRebar3 rec {
      name = "mochiweb";
      version = "3.2.2";

      src = fetchHex {
        pkg = "mochiweb";
        version = "${version}";
        sha256 = "4114e51f1b44c270b3242d91294fe174ce1ed989100e8b65a1fab58e0cba41d5";
      };

      beamDeps = [];
    };

    mox = buildMix rec {
      name = "mox";
      version = "1.0.2";

      src = fetchHex {
        pkg = "mox";
        version = "${version}";
        sha256 = "f9864921b3aaf763c8741b5b8e6f908f44566f1e427b2630e89e9a73b981fef2";
      };

      beamDeps = [];
    };

    parse_trans = buildRebar3 rec {
      name = "parse_trans";
      version = "3.4.1";

      src = fetchHex {
        pkg = "parse_trans";
        version = "${version}";
        sha256 = "620a406ce75dada827b82e453c19cf06776be266f5a67cff34e1ef2cbb60e49a";
      };

      beamDeps = [];
    };

    ssl_verify_fun = buildRebar3 rec {
      name = "ssl_verify_fun";
      version = "1.1.7";

      src = fetchHex {
        pkg = "ssl_verify_fun";
        version = "${version}";
        sha256 = "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8";
      };

      beamDeps = [];
    };

    unicode_util_compat = buildRebar3 rec {
      name = "unicode_util_compat";
      version = "0.7.1";

      src = fetchHex {
        pkg = "unicode_util_compat";
        version = "${version}";
        sha256 = "b3a917854ce3ae233619744ad1e0102e05673136776fb2fa76234f3e03b23642";
      };

      beamDeps = [];
    };
  };
in self

