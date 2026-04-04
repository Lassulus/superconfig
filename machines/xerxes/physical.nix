{ pkgs, ... }:
{
  imports = [
    ./disk.nix
    ./config.nix
    ./gpd-fan.nix
    ./gpd-win-mini-2025-pipewire.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.graphics.enable = true;

  # Load amdgpu early in initrd for reliable suspend/hibernate resume
  hardware.amdgpu.initrd.enable = true;

  # Disable Bluetooth USB autosuspend to prevent hardware errors/disconnects
  # Disable VPE (Video Processing Engine) to fix black screen after suspend/resume
  # on AMD Strix APUs. VPE fails to reset properly causing IB test timeouts.
  # https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2065365
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=0
    options amdgpu ip_block_mask=0xfffff7ff
  '';

  # Disable spurious wakeup sources that trigger immediate wake from s2idle
  # - PCIe ports
  # - USB host controllers (xhci_hcd) — external USB devices cause instant wakeup
  # - Thunderbolt controllers
  # - I2C touchpad/touchscreen (HTIX5288 via pinctrl_amd GPIO)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="thunderbolt", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="i2c", ATTR{name}=="HTIX5288*", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="serio", DRIVER=="atkbd", ATTR{power/wakeup}="disabled"
  '';

  # Disable ACPI wakeup on USB/Thunderbolt controllers to prevent spurious wakeups
  # (udev rules handle sysfs wakeup, this handles /proc/acpi/wakeup separately)
  systemd.services.disable-acpi-wakeup = {
    description = "Disable USB/Thunderbolt ACPI wakeup sources";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "disable-acpi-wakeup" ''
        for dev in XHC0 XHC1 XHC3 XHC4 NHI0 NHI1; do
          if grep -q "^$dev.*enabled" /proc/acpi/wakeup; then
            echo "$dev" > /proc/acpi/wakeup
          fi
        done
      '';
    };
  };

  # Swapfile for hibernation (suspend-then-hibernate needs somewhere to dump RAM)
  swapDevices = [
    {
      device = "/swapfile";
      size = 65536; # 64GB to cover full RAM
    }
  ];

  # Resume from swapfile on the root partition
  boot.resumeDevice = "/dev/disk/by-uuid/e2e38fb5-0cea-4a97-ae56-c2858ae0e07b";
  boot.kernelParams = [
    "resume_offset=156473344"
    "amdgpu.gpu_recovery=1" # attempt GPU reset on failure instead of black screen
    "amdgpu.dcdebugmask=0x10" # disable DSC to prevent GPU hang with external displays
  ];

  # Pre-evict VRAM before sleep to prevent amdgpu resume black screen
  # https://nyanpasu64.gitlab.io/blog/amdgpu-sleep-wake-hang/
  systemd.services.amdgpu-sleep = {
    description = "Evict VRAM before sleep";
    before = [
      "sleep.target"
      "suspend.target"
      "hibernate.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "sleep.target"
      "suspend.target"
      "hibernate.target"
      "suspend-then-hibernate.target"
    ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'for f in /sys/kernel/debug/dri/*/amdgpu_evict_vram; do cat \"$f\"; done'";
    };
  };

  # Unbind USB4/Thunderbolt controllers before sleep to allow s0ix deepest state
  # AMD USB4 controllers stay active during s2idle and block entry into deepest sleep
  # XHCI (USB3) controllers are left bound to avoid disconnecting gamepad/keyboard/mouse
  environment.etc."systemd/system-sleep/usb4-sleep".source = pkgs.writeShellScript "usb4-sleep" ''
    case "$1" in
      pre)
        for dev in 0000:c6:00.5 0000:c6:00.6; do
          if [ -e /sys/bus/pci/drivers/thunderbolt/$dev ]; then
            echo $dev > /sys/bus/pci/drivers/thunderbolt/unbind || true
          fi
        done
        ;;
      post)
        for dev in 0000:c6:00.5 0000:c6:00.6; do
          if [ ! -e /sys/bus/pci/drivers/thunderbolt/$dev ]; then
            echo $dev > /sys/bus/pci/drivers/thunderbolt/bind || true
          fi
        done
        ;;
    esac
  '';

  # s2idle for 15 minutes, then hibernate to save power
  services.logind.powerKey = "suspend-then-hibernate";
  services.logind.lidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep = {
    SuspendMode = "s2idle";
    SuspendState = "mem";
    HibernateDelaySec = "15min";
  };
}
