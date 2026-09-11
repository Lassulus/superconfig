{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage {
  pname = "tincr";
  version = "0-unstable-2026-09-07";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "tincr";
    rev = "da74995ab9257057dcfce1d8b12926c77d81bc43";
    hash = "sha256-oslhal/av02Ov8WOhgwVu14Juibrs7G/qVN5cA9Dqvo=";
  };

  cargoHash = "sha256-IaVZzNWxVIpzlLtE4xzt+gIBeIV6xX4/3C/eh1tlE04=";

  # Just the deployable bin crates; --workspace would pull tinc-ffi's cc.
  cargoBuildFlags = [
    "-p"
    "tincd"
    "-p"
    "tinc-tools"
  ];

  # netns tests need bwrap+userns the build sandbox lacks.
  doCheck = false;

  # tinc-crypto's ChaPoly backend links openssl-sys against system openssl.
  nativeBuildInputs = [
    installShellFiles
    pkg-config
  ];
  buildInputs = [ openssl ];

  postInstall = ''
    installManPage man/*.[0-9]
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Drop-in Rust rewrite of tinc 1.1 VPN (SPTPS-only, Ed25519)";
    homepage = "https://github.com/Mic92/tincr";
    license = lib.licenses.gpl2Plus;
    mainProgram = "tincd";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
