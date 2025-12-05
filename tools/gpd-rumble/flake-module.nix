{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.gpd-rumble = pkgs.stdenv.mkDerivation {
        pname = "gpd-rumble";
        version = "0.1.0";

        src = ./.;

        buildInputs = [ ];

        buildPhase = ''
          $CC -o gpd-rumble rumble.c
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp gpd-rumble $out/bin/
        '';

        meta = {
          description = "Trigger vibration motor on GPD Win Mini 2025";
          platforms = lib.platforms.linux;
          mainProgram = "gpd-rumble";
        };
      };
    };
}
