{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:

rustPlatform.buildRustPackage {
  pname = "tincr";
  version = "0-unstable-2026-05-15";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "tincr";
    rev = "7f622240";
    hash = "sha256-V1Q7G/PP0w5iDgvIntU4YStniLBb6OUg6F1aMfRl84M=";
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
