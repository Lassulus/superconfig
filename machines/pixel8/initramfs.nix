{
  pkgsCross,
  makeInitrdNG,
  writeScript,
  callPackage,
}:

let
  # Use aarch64 cross-compiled packages
  aarch64 = pkgsCross.aarch64-multiplatform;

  kernel = callPackage ./kernel.nix { };

  # Modules needed for USB keyboard support
  usbModules = [
    "phy-exynos-usbdrd-eusb-super.ko"
    "eusb_repeater.ko"
    "dwc3-exynos-usb.ko"
    "xhci-exynos.ko"
    "xhci-goog-dma.ko"
  ];

  # Minimal init script that loads USB modules and drops to shell
  initScript = writeScript "init" ''
    #!/bin/busybox sh

    # Mount essential filesystems
    /bin/busybox mkdir -p /proc /sys /dev /tmp /run /lib/modules
    /bin/busybox mount -t proc proc /proc
    /bin/busybox mount -t sysfs sys /sys
    /bin/busybox mount -t devtmpfs dev /dev
    /bin/busybox mount -t tmpfs tmp /tmp

    # Setup busybox symlinks early
    /bin/busybox --install -s /bin

    # Print banner
    echo ""
    echo "====================================="
    echo "  NixOS Mobile - Pixel 8 Debug Shell"
    echo "====================================="
    echo ""

    # Load USB modules for keyboard support
    echo "Loading USB modules..."
    for mod in ${builtins.concatStringsSep " " usbModules}; do
      if [ -f "/lib/modules/$mod" ]; then
        echo "  Loading $mod"
        insmod "/lib/modules/$mod" 2>/dev/null || echo "    (failed or already loaded)"
      fi
    done

    echo ""
    echo "Kernel: $(uname -r)"
    echo ""
    echo "USB keyboard should work if connected via OTG adapter."
    echo "If no input works, try connecting via USB serial/ADB."
    echo ""

    # Try to get a console - attempt multiple TTYs
    for console in /dev/console /dev/tty0 /dev/tty1 /dev/ttyGS0; do
      if [ -e "$console" ]; then
        echo "Attempting shell on $console"
        exec setsid sh -c "exec sh <$console >$console 2>&1"
      fi
    done

    # Fallback - just exec shell
    exec /bin/sh
  '';

  # Create module directory structure
  moduleContents = map (mod: {
    source = "${kernel}/modules/${mod}";
    target = "/lib/modules/${mod}";
  }) usbModules;

in
makeInitrdNG {
  compressor = "gzip";

  contents = [
    {
      # Use statically-linked aarch64 busybox
      source = "${aarch64.busybox-sandbox-shell}";
      target = "/bin/busybox";
    }
    {
      source = initScript;
      target = "/init";
    }
  ] ++ moduleContents;
}
