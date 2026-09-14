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
  version = "0-unstable-2026-09-14";

  # Our fork's fix branch until Mic92/tincr#101 lands: NAT-leaf dial
  # (#100), stale-loop-clock auth timeouts, tunnel-address gate.
  src = fetchFromGitHub {
    owner = "Lassulus";
    repo = "tincr";
    rev = "44220d98a08c73eaf61f5e75f6743843bfd58746";
    hash = "sha256-K4iHJX3qHwgVXB6X05of1sjB57qMzY5mGCYuPODiHwY=";
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
