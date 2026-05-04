{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:

rustPlatform.buildRustPackage {
  pname = "tincr";
  version = "0-unstable-2026-04-29";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "tincr";
    rev = "acb15fc2e203652f70d2a8c24d2c35d73c396572";
    hash = "sha256-qQ35osywm1Z8zfN+GYy7wxhG9bQ7U7X1Y+ETmZ6p2nw=";
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
