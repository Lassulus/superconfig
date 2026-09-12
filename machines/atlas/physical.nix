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
    # Two boot media from one config. Every entry in image.modules is applied
    # to this config through its own extendModules, so the iso and netboot
    # variants never see each other's fileSystems / bootloader definitions —
    # no disabledModules or mkForce juggling needed.
    #
    #   nixos-rebuild build-image --flake .#atlas --image-variant iso
    #   nix build .#nixosConfigurations.atlas.config.system.build.images.iso
    #   nix build .#atlas-netboot-root      (kernel+initrd+ipxe for PXE)
    (modulesPath + "/image/images.nix")
  ];

  # Deliberately no image module at the toplevel: nixpkgs warns that doing so
  # defines system.build.image and leaks the medium into every variant. That
  # leaves the base config without a real boot medium, so these two
  # placeholders exist only to let it evaluate; both image variants override
  # the root with mkImageMediaOverride (priority 60), which wins over these.
  # The base toplevel itself is never booted or deployed.
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
  };
  boot.loader.grub.enable = lib.mkDefault false;

  # Live USB stick: store is a squashfs on the stick, root a tmpfs overlay on
  # top. Stateless, nothing installed — dd it and boot.
  #
  # The built-in `iso` variant is iso-image.nix (not installation-cd-base):
  # no nixos channel, no installer profile, no `nixos` autologin to fight
  # greetd or clash with 2configs/pinned-registry.nix. Settings here merge
  # into it, since image.modules is an attrsOf deferredModule.
  image.modules.iso = {
    # zstd keeps the squashfs small without a slow xz build.
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
    isoImage.makeEfiBootable = true;
    isoImage.makeUsbBootable = true;
    image.baseName = lib.mkForce "atlas";
    image.fileName = lib.mkForce "atlas.iso";
  };

  # PXE/netboot: iPXE pulls only bzImage + a ~11 MB initrd, so nothing has to
  # be flashed to iterate.
  #
  # The store is NOT embedded in the initrd the way upstream netboot.nix does
  # it. iPXE has to hold whatever it downloads in EfiBootServicesData, and
  # firmware caps that well below installed RAM — a 2.8 GB initrd died with
  # "No space left on device" (ipxe.org/34182006) on a 16 GB machine. So stage
  # 1 brings up the network itself and fetches the squashfs, which lands in
  # kernel-managed memory where the whole 16 GB is actually usable.
  #
  # The file is fetched to exactly the path netboot.nix already mounts from
  # ("../nix-store.squashfs", i.e. /nix-store.squashfs in the initrd root), so
  # the mount itself is upstream's, unmodified. It survives switch_root
  # because the loop device keeps the inode open after the old root is wiped.
  image.modules.netboot =
    { config, lib, ... }:
    {
      imports = [ (modulesPath + "/installer/netboot/netboot.nix") ];
      netboot.squashfsCompression = "zstd -Xcompression-level 6";

      # Ship the initrd without the store; pxe-serve serves squashfsStore
      # separately over HTTP.
      system.build.netbootRamdisk = lib.mkForce config.system.build.initialRamdisk;

      # DHCP in stage 1 (runs in preLVMCommands, before postDeviceCommands).
      boot.initrd.network.enable = true;
      boot.initrd.network.udhcpc.enable = true;

      # hardware.enableAllHardware is storage-only — virtio_net is the single
      # network driver in its 89 modules — so wired NICs have to be listed by
      # hand. availableKernelModules only makes them available; udev loads just
      # the ones matching present PCI/USB IDs, so unused entries cost bytes.
      boot.initrd.availableKernelModules = [
        "e1000e"
        "e1000"
        "igb"
        "igc"
        "ixgbe"
        "r8169"
        "alx"
        "atl1c"
        "tg3"
        "bnx2"
        "bnx2x"
        "sky2"
        "forcedeth"
        "atlantic"
        # USB NICs (docks, adapters)
        "r8152"
        "cdc_ether"
        "cdc_ncm"
        "asix"
        "ax88179_178a"
        "virtio_net"
      ];

      # wget is busybox's, already present in the scripted initrd's
      # extra-utils. The URL comes from the kernel command line rather than
      # being baked in, so the image doesn't go stale when the serving address
      # changes (pxe-serve passes store.url=).
      boot.initrd.postDeviceCommands = ''
        store_url=
        for o in $(cat /proc/cmdline); do
          case $o in
            store.url=*) store_url=''${o#store.url=} ;;
          esac
        done
        if [ -z "$store_url" ]; then
          echo "netboot: no store.url= on the kernel command line"
          fail
        fi
        echo "netboot: fetching nix store from $store_url"
        if ! wget -O /nix-store.squashfs "$store_url"; then
          echo "netboot: failed to fetch $store_url"
          fail
        fi
      '';
    };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AMD Radeon (Navi 14 / RX 5500-class, PCI 1002:7340) -> amdgpu.
  #
  # amdgpu is deliberately NOT in boot.initrd.kernelModules: early-loading it
  # tears down efifb before the GPU firmware is available in stage-1, which
  # black-screens this card from the moment the kernel starts (measured: ~5min
  # to reach systemd). Let udev load amdgpu in stage-2, where the firmware is
  # present. hardware.amdgpu.initrd.enable is the same trap — it only adds the
  # module and handles no firmware.
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;

  # No 32-bit graphics stack: it drags in a second mesa plus a second LLVM
  # (~840 MB uncompressed) and is only needed for Steam/Wine, which this
  # stateless box doesn't run. Both image variants pay for it otherwise, and
  # the netboot initrd has to fit under iPXE's sub-4GB allocation limit.
  hardware.graphics.enable32Bit = false;

  # nixpkgs' graphical-desktop.nix turns on speech-dispatcher for any
  # graphical session, which pulls espeak and 676 MB of mbrola TTS voices.
  # Nothing here speaks.
  services.speechd.enable = lib.mkForce false;
  services.xserver.videoDrivers = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Boot the live image off a USB mass-storage device. (Inert for netboot,
  # where iPXE has already fetched kernel+initrd before the kernel starts.)
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "uas"
    "usbhid"
    "sd_mod"
  ];

  # Initrd size dominates boot for both media: GRUB reads it off USB at
  # roughly 1 MB/s (measured: 59s loader phase vs 6.5s kernel + 4.5s initrd +
  # 10s userspace), and for netboot it travels with the store image.
  #
  # It was 29 MB compressed / 83 MB unpacked, of which only 1.8 MB was kernel
  # modules — the rest was the systemd-initrd closure (openssl, lvm2,
  # cryptsetup, tpm2-tss, curl, krb5, bash-interactive). Stage 1 only has to
  # find the boot medium and mount squashfs+overlay: no LUKS, no LVM, no TPM,
  # no network. The scripted initrd drops that closure: 29 MB -> 11 MB.
  boot.initrd.systemd.enable = lib.mkForce false;
  boot.initrd.systemd.emergencyAccess = lib.mkForce false;
  boot.initrd.services.lvm.enable = lib.mkForce false;

  # Name the onboard Intel NIC deterministically.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ATTR{address}=="70:85:c2:0e:ea:3c", NAME="et0"
  '';

  # Stateless box: no clan secrets are deployed, so don't try to load an
  # openssh host key from a vars path that will never exist on the live
  # system. Let sshd generate an ephemeral key at boot instead.
  services.openssh.hostKeys = lib.mkForce [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
}
