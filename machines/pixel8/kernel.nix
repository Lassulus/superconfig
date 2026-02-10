{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  lz4,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pixel8-kernel-grapheneos";
  version = "6.1-16-qpr2";

  src = fetchFromGitHub {
    owner = "GrapheneOS";
    repo = "device_google_shusky-kernels_6.1";
    rev = "16-qpr2";
    hash = "sha256-bFYP0gdPQiQEf4wjwGyE8ocfKeYOWPLSBtkif3SDvzM=";
  };

  nativeBuildInputs = [ lz4 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{kernel,dtbs,modules}

    # Decompress kernel
    lz4 -d grapheneos/Image.lz4 $out/kernel/Image

    # Copy DTBs
    cp grapheneos/*.dtb $out/dtbs/

    # Copy DTBO image
    cp grapheneos/dtbo.img $out/

    # Copy all modules
    cp grapheneos/*.ko $out/modules/

    # Copy module loading configuration
    cp grapheneos/modules.load $out/
    cp grapheneos/init.insmod.shiba.cfg $out/
    cp grapheneos/vendor_kernel_boot.modules.load $out/

    # Copy System.map for debugging
    cp grapheneos/System.map $out/

    runHook postInstall
  '';

  # No compilation, just file copies - can build on any platform
  dontStrip = true;
  dontPatchELF = true;
  dontFixup = true;

  meta = with lib; {
    description = "GrapheneOS prebuilt kernel for Google Pixel 8 (shiba)";
    homepage = "https://github.com/GrapheneOS/device_google_shusky-kernels_6.1";
    license = licenses.gpl2Only;
    # Contains aarch64 binaries, but can be unpacked on any platform
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
