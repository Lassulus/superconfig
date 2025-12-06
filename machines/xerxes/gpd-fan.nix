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

  hardware.fancontrol = {
    enable = true;
    config = ''
      INTERVAL=2
      DEVPATH=hwmon2=devices/platform/gpd_fan hwmon6=devices/pci0000:00/0000:00:18.3
      DEVNAME=hwmon2=gpdfan hwmon6=k10temp
      FCTEMPS=hwmon2/pwm1=hwmon6/temp1_input
      FCFANS=hwmon2/pwm1=hwmon2/fan1_input
      MINTEMP=hwmon2/pwm1=45
      MAXTEMP=hwmon2/pwm1=85
      MINSTART=hwmon2/pwm1=40
      MINSTOP=hwmon2/pwm1=30
      MINPWM=hwmon2/pwm1=0
      MAXPWM=hwmon2/pwm1=255
    '';
  };
}
