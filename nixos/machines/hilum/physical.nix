{ config, lib, pkgs, ... }:

{
  imports = [
    ./config.nix
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    {
      # nice hack to carry around state passed impurely at the beginning
      options.mainDisk = let
        tryFile = path: default:
          if lib.elem (builtins.baseNameOf path) (lib.attrNames (builtins.readDir (builtins.dirOf path))) then
            builtins.readFile path
          else
            default
          ;
      in lib.mkOption {
        type = lib.types.str;
        default = tryFile "/etc/hilum-disk" (tryFile "/tmp/hilum-disk" "/dev/sdz");
      };
      config.environment.etc.hilum-disk.text = config.mainDisk;
    }
    {
      options.luksPassFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
    }
  ];

  disko.devices = import ./disk.nix {
    inherit lib;
    disk = config.mainDisk;
    keyFile = config.luksPassFile;
  };

  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "xhci_pci" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = config.mainDisk;
  boot.loader.grub.efiInstallAsRemovable = true;

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  #weird bug with nixos-enter
  services.logrotate.enable = false;
}
