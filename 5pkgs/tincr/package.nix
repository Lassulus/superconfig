{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:

rustPlatform.buildRustPackage {
  pname = "tincr";
  version = "0-unstable-2026-05-11-lass-udpfix";

  src = fetchFromGitHub {
    owner = "Lassulus";
    repo = "tincr";
    rev = "a25eec05b639a48bb164b41b5a1ae770ea6252d2";
    hash = "sha256-kobvGKOcB56efbOq0xSM4dLF5JhQPne+VQ+KRrU/kjo=";
  };

  cargoHash = "sha256-3zq9SoOiBRqwXWr7N0NRW+oM2OLu8/IY3B3WCCZ0Chw=";

  # Just the deployable bin crates; --workspace would pull tinc-ffi's cc.
  cargoBuildFlags = [
    "-p"
    "tincd"
    "-p"
    "tinc-tools"
  ];

  # netns tests need bwrap+userns the build sandbox lacks.
  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installManPage man/*.[0-9]
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Drop-in Rust rewrite of tinc 1.1 VPN (SPTPS-only, Ed25519)";
    homepage = "https://github.com/Mic92/tincr";
    license = lib.licenses.gpl2Plus;
    mainProgram = "tincd";
    platforms = lib.platforms.linux;
  };
}
