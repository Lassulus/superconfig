{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  nettle,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "age-plugin-gpg";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "CertainLach";
    repo = "age-plugin-gpg";
    rev = "v${finalAttrs.version}";
    hash = "sha256-HfCl+YAjKPNFtLAHjNyjlHhRxD85qZLWsfKzqORtj5U=";
  };

  cargoLock = {
    lockFile = "${finalAttrs.src}/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [ nettle ];

  meta = {
    description = "Age plugin utilizing gpg-agent & keygrips as recipients/identities";
    homepage = "https://github.com/CertainLach/age-plugin-gpg";
    license = lib.licenses.mit;
    mainProgram = "age-plugin-gpg";
    platforms = lib.platforms.unix;
    maintainers = [ ];
  };
})
