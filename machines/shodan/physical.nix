{ self, ... }:
{
  imports = [
    ./config.nix
    ./disk.nix
    self.inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNX0H662201F";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ATTR{address}=="a0:88:b4:29:26:bc", NAME="wl0"
    SUBSYSTEM=="net", ATTR{address}=="f0:de:f1:0c:a7:63", NAME="et0"
    SUBSYSTEM=="net", ATTR{address}=="00:e0:4c:69:ea:71", NAME="int0"
  '';
}
