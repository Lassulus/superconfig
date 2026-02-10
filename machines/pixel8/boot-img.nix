{
  lib,
  stdenvNoCC,
  callPackage,
}:

let
  kernel = callPackage ./kernel.nix { };
  initramfs = callPackage ./initramfs.nix { };
  mkbootimg = callPackage ./mkbootimg.nix { };
in
stdenvNoCC.mkDerivation {
  pname = "pixel8-boot-img";
  version = "0.1.0";

  dontUnpack = true;

  nativeBuildInputs = [ mkbootimg ];

  buildPhase = ''
    runHook preBuild

    # Create boot.img for Pixel 8
    # Using boot header version 4 for Android 12+ devices
    mkbootimg \
      --kernel ${kernel}/kernel/Image \
      --ramdisk ${initramfs}/initrd \
      --header_version 4 \
      --os_version 14.0.0 \
      --os_patch_level 2024-01 \
      --pagesize 4096 \
      --output boot.img

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp boot.img $out/

    # Also provide the components separately for debugging
    mkdir -p $out/components
    ln -s ${kernel} $out/components/kernel
    ln -s ${initramfs}/initrd $out/components/initrd
    ln -s ${kernel}/dtbo.img $out/dtbo.img

    # Create a flash script
    cat > $out/flash.sh << 'EOF'
    #!/bin/sh
    set -e
    echo "Flashing Pixel 8 boot image..."
    echo "Make sure device is in fastboot mode (power + volume down)"
    echo ""
    echo "To flash temporarily (will revert on reboot):"
    echo "  fastboot boot ${placeholder "out"}/boot.img"
    echo ""
    echo "To flash permanently (DANGER - can brick device):"
    echo "  fastboot flash boot ${placeholder "out"}/boot.img"
    echo ""
    echo "To flash DTBO (may be needed):"
    echo "  fastboot flash dtbo ${placeholder "out"}/dtbo.img"
    EOF
    chmod +x $out/flash.sh

    runHook postInstall
  '';

  meta = with lib; {
    description = "Minimal NixOS boot image for Google Pixel 8";
    license = licenses.gpl2Only;
    platforms = platforms.all;
  };
}
