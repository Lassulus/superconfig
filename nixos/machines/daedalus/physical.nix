{
  imports = [
    ./config.nix
    <stockholm/lass/2configs/hw/x220.nix>
    <stockholm/lass/2configs/boot/coreboot.nix>
  ];

  fileSystems = {
    "/bku" = {
      device = "/dev/mapper/pool-bku";
      fsType = "btrfs";
      options = ["defaults" "noatime" "ssd" "compress=lzo"];
    };
    "/backups" = {
      device = "/dev/pool/backup";
      fsType = "ext4";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ATTR{address}=="08:11:96:0a:5d:6c", NAME="wl0"
    SUBSYSTEM=="net", ATTR{address}=="f0:de:f1:71:cb:35", NAME="et0"
  '';
}
