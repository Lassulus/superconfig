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

  # Disable spurious wakeup sources (PCIe ports triggering immediate wake from s2idle)
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"
  '';

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

  # s2idle for 15 minutes, then hibernate to save power
  services.logind.powerKey = "suspend-then-hibernate";
  services.logind.lidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep = {
    SuspendMode = "s2idle";
    SuspendState = "mem";
    HibernateDelaySec = "15min";
  };
}
