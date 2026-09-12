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

  # PXE/netboot: iPXE pulls bzImage + initrd, so nothing has to be flashed to
  # iterate. The whole store rides inside the initrd (~3.8 GB), which is why
  # it has to be served over HTTP rather than TFTP — see nat-share --pxe/--http.
  image.modules.netboot = {
    imports = [ (modulesPath + "/installer/netboot/netboot.nix") ];
    netboot.squashfsCompression = "zstd -Xcompression-level 6";
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
  hardware.graphics.enable32Bit = true;
  hardware.enableRedistributableFirmware = true;
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
