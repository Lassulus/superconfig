{ pkgs, ... }:

let
  dummy_firmware = pkgs.writeTextFile {
    name = "brcmfmac4356-pcie.txt";
    text = builtins.readFile ./brcmfmac4356-pcie.txt;
    destination = "/lib/firmware/brcm/brcmfmac4356-pcie.txt";
  };
in {
  #imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];
  hardware.firmware = [ dummy_firmware ];
  hardware.enableRedistributableFirmware = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sdhci_acpi" "sdhci_pci" ];
  boot.kernelPackages = pkgs.linuxPackages_4_14;
  boot.kernelParams = [
    "fbcon=rotate:1"
  ];
  services.xserver.displayManager.sessionCommands = ''
    (sleep 2 && ${pkgs.xorg.xrandr}/bin/xrandr --output DSI1 --rotate right)
    (sleep 2 && ${pkgs.xorg.xinput}/bin/xinput set-prop 'Goodix Capacitive TouchScreen' 'Coordinate Transformation Matrix' 0 1 0 -1 0 1 0 0 1)
  '';
  services.xserver.dpi = 200;
  fonts.fontconfig.dpi = 200;
  lass.fonts.regular = "xft:Hack-Regular:pixelsize=22,xft:Symbola";
  lass.fonts.bold =    "xft:Hack-Bold:pixelsize=22,xft:Symbola";
  lass.fonts.italic =  "xft:Hack-RegularOblique:pixelsize=22,xft:Symbol";
}
