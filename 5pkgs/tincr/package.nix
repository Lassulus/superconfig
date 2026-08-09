{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:

rustPlatform.buildRustPackage {
  pname = "tincr";
  version = "0-unstable-2026-08-09";

  # Lassulus/tincr = upstream main + fix/pmtu-blackhole-recovery. Point
  # back at Mic92/main (and revert update.sh) once that lands upstream.
  # Without it a UDP path that dies after being confirmed is never
  # abandoned: udp_confirmed stays pinned, maxmtu sticks at 0, and the
  # peer logs "Fixing MTU ... to 0" every 3.4s forever. Bites any two
  # nodes behind the same non-hairpinning NAT (ignavia <-> coaxmetal).
  src = fetchFromGitHub {
    owner = "Lassulus";
    repo = "tincr";
    rev = "32a10488622ad271942078712c3708cab66347ba";
    hash = "sha256-zagrdeJIhS6G0fDjf2tM5oA3HS9kX42UuVm8zOqVvtE=";
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
