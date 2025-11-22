{ config, pkgs, ... }:
let
  gpd-fan = config.boot.kernelPackages.callPackage (
    { stdenv, kernel }:
    stdenv.mkDerivation {
      pname = "gpd-fan-driver";
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "Cryolitia";
        repo = "gpd-fan-driver";
        rev = "a400c7d2d7b0bd150f0f7148a10eea816d16314e";
        hash = "sha256-W+1OCiDxFHHAC9pPq1t6u4bLubj/4nNl2cep/HYYAgs=";
      };

      hardeningDisable = [ "pic" ];

      nativeBuildInputs = kernel.moduleBuildDependencies;

      makeFlags = [
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];

      installPhase = ''
        runHook preInstall
        install *.ko -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/gpdfan
        runHook postInstall
      '';
    }
  ) { };
in
{
  boot.extraModulePackages = [ gpd-fan ];
  boot.kernelModules = [ "gpd_fan" ];
}
