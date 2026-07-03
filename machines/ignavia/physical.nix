{
  self,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    ./config.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk.nix
    self.inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  services.fprintd.enable = true;
  services.fwupd.enable = true;
  services.fwupd.extraRemotes = [ "lvfs-testing" ];
  # Might be necessary once to make the update succeed
  # services.fwupd.uefiCapsuleSettings.DisableCapsuleUpdateOnDisk = true;
  # we need fwupd 1.9.7 to downgrade the fingerprint sensor firmware
  # we only need to downgrade the firmware once, so we can remove this once we have done that
  # services.fwupd.package = (import (builtins.fetchTarball {
  #   url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
  #   sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
  # }) {
  #   inherit (pkgs) system;
  # }).fwupd;

  networking.hostId = "deadbeef";

  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    efiSupport = true;
    efiInstallAsRemovable = true;
    # The ESP is only 1 GiB (see disk.nix); without a cap GRUB keeps every
    # generation's kernel+initrd (~50-90 MiB each) until /boot fills and
    # deploys fail. ~10 generations fits with headroom.
    configurationLimit = 10;
  };

  hardware.graphics.enable = true;
  hardware.acpilight.enable = true;

  # Use latest kernel for better Strix Point GPU support. The MT7925 BT init
  # regression fix (e3ac0d9f1a20) landed upstream in 7.0.10.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # MT7925 WiFi: wcid poll-list corruption on station removal during AP
  # roaming -> list_add corruption -> kernel BUG at lib/list_debug.c:32
  # -> hard freeze. Three freezes on 2026-07-03 alone (multi-AP ESS).
  # Local fix, see patch header for full analysis; related upstream work:
  # https://github.com/zbowling/mt7925 (series not yet merged, and the
  # already-merged parts in 7.1.x do not close this race).
  # Drop once the fix (or equivalent) lands upstream.
  boot.kernelPatches = [
    {
      name = "mt76-wcid-poll-race";
      patch = ./mt76-wcid-poll-race.patch;
    }
  ];

  # amdgpu.mes=0 (old RDNA3+ MES ring-hang workaround) was removed here:
  # since kernel ~7.x the parameter no longer exists ("amdgpu: unknown
  # parameter 'mes' ignored") and the GPU has been stable without it.

  boot.initrd.availableKernelModules = [
    "nvme"
    "thunderbolt"
    "xhci_pci"
    "usbhid"
  ];

  # IO latency tuning. The whole system (/, /home, /nix) lives on one
  # btrfs-on-LUKS-on-NVMe device, so bulk writes (downloads, builds) can starve
  # latency-sensitive reads — e.g. launching a terminal stalls for seconds.
  # Three independent causes, three fixes:

  # 1. NVMe defaults to scheduler "none" (FIFO, no read/write fairness), so a
  #    read queues behind up to nr_requests (1023) writes. mq-deadline gives
  #    reads deadline priority over bulk writes.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="mq-deadline"
  '';

  # 2. Default dirty-page limits are ratio-based: ~6.2 GB background / ~12.4 GB
  #    hard on 62 GB RAM. Writes pool in RAM then flush in multi-GB bursts that
  #    flood the queue and freeze everything (PSI full IO). Small fixed byte
  #    limits make writeback continuous instead of bursty.
  boot.kernel.sysctl."vm.dirty_bytes" = 268435456; # 256 MiB
  boot.kernel.sysctl."vm.dirty_background_bytes" = 67108864; # 64 MiB

  # 3. dm-crypt funnels all IO through the kcryptd workqueue, a serialization
  #    point under load. AES-NI is present so inline crypto is cheap — bypass
  #    the queues to cut crypt-layer latency. Device name from disk.nix.
  boot.initrd.luks.devices.aergia1.bypassWorkqueues = true;
}
