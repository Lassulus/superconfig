{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./config.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  boot.blacklistedKernelModules = [
    "sdhci_pci"
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.luks.devices.crypted.device = "/dev/sda3";
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [
    "fbcon=rotate:1"
    "boot.shell_on_fail"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/8efd0c22-f712-46bf-baad-1fbf19d9ec25";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/7F23-DDB4";
    fsType = "vfat";
  };

  swapDevices = [ ];

  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=107374182
  '';

  nix.maxJobs = lib.mkDefault 4;

  networking.hostId = "9b0a74ac";
  networking.networkmanager.enable = true;

  hardware.opengl.enable = true;

  services.tlp.enable = true;
  services.tlp.extraConfig = ''
    CPU_SCALING_GOVERNOR_ON_AC=ondemand
    CPU_SCALING_GOVERNOR_ON_BAT=powersave
    CPU_MIN_PERF_ON_AC=0
    CPU_MAX_PERF_ON_AC=100
    CPU_MIN_PERF_ON_BAT=0
    CPU_MAX_PERF_ON_BAT=30
  '';

  services.logind.extraConfig = ''
    HandlePowerKey=suspend
    IdleAction=suspend
    IdleActionSec=300
  '';

  services.xserver = {
    videoDrivers = [ "intel" ];
    displayManager.sessionCommands = ''
      (sleep 2 && ${pkgs.xorg.xrandr}/bin/xrandr --output eDP1 --rotate right)
      (sleep 2 && ${pkgs.xorg.xinput}/bin/xinput set-prop "pointer:Goodix Capacitive TouchScreen" --type=float "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1)
    '';
  };
}
