{ ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages = {
        # GrapheneOS prebuilt kernel for Pixel 8
        pixel8-kernel = pkgs.callPackage ./kernel.nix { };

        # Android boot image tools
        mkbootimg = pkgs.callPackage ./mkbootimg.nix { };

        # Minimal initramfs with debug shell
        pixel8-initramfs = pkgs.callPackage ./initramfs.nix { };

        # Complete boot image ready to flash
        pixel8-boot-img = pkgs.callPackage ./boot-img.nix { };
      };
    };
}
