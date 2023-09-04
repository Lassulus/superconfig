{
  #TODO reinstall with correct layout and use lass/hw/x220
  imports = [
    ./config.nix
    <stockholm/krebs/2configs/hw/x220.nix>
  ];

  boot = {
    loader.grub.enable = true;
    loader.grub.version = 2;
    loader.grub.device = "/dev/sda";

    initrd.luks.devices.lusksroot.device = "/dev/sda2";
    initrd.availableKernelModules = [ "xhci_hcd" "ehci_pci" "ahci" "usb_storage" ];
  };
  fileSystems = {
    "/" = {
      device = "/dev/pool/nix";
      fsType = "btrfs";
    };

    "/boot" = {
      device = "/dev/sda1";
    };
    "/home" = {
      device = "/dev/mapper/pool-home";
      fsType = "btrfs";
      options = ["defaults" "noatime" "ssd" "compress=lzo"];
    };
    "/bku" = {
      device = "/dev/pool/bku";
      fsType = "btrfs";
    };
    "/backups" = {
      device = "/dev/pool/backup";
      fsType = "ext4";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ATTR{address}=="a0:88:b4:29:26:bc", NAME="wl0"
    SUBSYSTEM=="net", ATTR{address}=="f0:de:f1:0c:a7:63", NAME="et0"
    SUBSYSTEM=="net", ATTR{address}=="00:e0:4c:69:ea:71", NAME="int0"
  '';
}
