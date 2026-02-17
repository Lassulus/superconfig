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

    # Create init_boot.img for Pixel 8 (Android 13+)
    # This replaces only the init ramdisk, keeping GrapheneOS kernel + vendor_boot
    # Header version 4, no kernel - just our ramdisk with /init
    mkbootimg \
      --header_version 4 \
      --ramdisk ${initramfs}/initrd \
      --os_version 14.0.0 \
      --os_patch_level 2024-01 \
      --pagesize 4096 \
      --output init_boot.img

    # Also create full boot.img for reference/testing
    mkbootimg \
      --kernel ${kernel}/kernel/Image \
      --ramdisk ${initramfs}/initrd \
      --header_version 4 \
      --os_version 14.0.0 \
      --os_patch_level 2024-01 \
      --pagesize 4096 \
      --cmdline "rdinit=/init" \
      --output boot.img

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp init_boot.img $out/
    cp boot.img $out/

    # Also provide the components separately for debugging
    mkdir -p $out/components
    ln -s ${kernel} $out/components/kernel
    ln -s ${initramfs}/initrd $out/components/initrd
    ln -s ${kernel}/dtbo.img $out/dtbo.img

    runHook postInstall
  '';

  meta = with lib; {
    description = "Minimal NixOS boot image for Google Pixel 8";
    license = licenses.gpl2Only;
    platforms = platforms.all;
  };
}
