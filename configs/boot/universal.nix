{ ... }:

{
  boot = {
    loader.grub.enable = true;
    loader.grub.version = 2;
    loader.grub.device = "/dev/sda";
    loader.grub.efiSupport = true;
    loader.grub.efiInstallAsRemovable = true;
  };
}
