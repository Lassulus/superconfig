{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "phonetpm";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Lassulus";
    repo = "phonetpm";
    tag = "v${version}";
    hash = "sha256-8WjjbDDHZeYhtnoj/judDrsWT68Z4lnpySM8rSqP+Ao=";
  };

  cargoHash = "sha256-VNw5Hw8E0ReSJhYVLh6XOzQRSyqfFe3uu0522XOeaoA=";

  # Host side only: `phonetpm` (daemon/pair/keys) and `age-plugin-phone`.
  # The workspace also holds the Android core (uniffi cdylib), not needed here.
  cargoBuildFlags = [
    "-p"
    "phonetpm"
  ];
  cargoTestFlags = cargoBuildFlags;

  meta = {
    description = "Android phone as a biometric ssh-agent and age backend over iroh";
    homepage = "https://github.com/Lassulus/phonetpm";
    license = lib.licenses.mit;
    mainProgram = "phonetpm";
    platforms = lib.platforms.linux;
  };
}
