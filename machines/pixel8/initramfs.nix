{
  pkgsCross,
  stdenvNoCC,
  writeScript,
  callPackage,
  cpio,
  gzip,
}:

let
  # Use aarch64 cross-compiled packages
  aarch64 = pkgsCross.aarch64-multiplatform;
  busybox = aarch64.busybox.override { enableStatic = true; };

  kernel = callPackage ./kernel.nix { };

  # Modules needed for USB (and their full dependency chain)
  # Traced via modinfo -F depends, topologically sorted
  usbModules = [
    # Leaf dependencies (no deps of their own)
    "ect_parser"
    "eusb_repeater"
    "exynos-pd_el3"
    "google_tcpci_shim"
    "gs-chipid"
    "gs_perf_mon"
    "gvotable"
    "kernel-top"
    "logbuffer"
    "max77759_helper"
    "pixel-suspend-diag"
    "sched_tp"
    "systrace"
    "xhci-goog-dma"
    # Level 1
    "exynos-pmu-if"
    "dss"
    "exynos-pd_hsi0"
    "usb_psy"
    "max77759_contaminant"
    "max77779_contaminant"
    "pinctrl-exynos-gs"
    # Level 2
    "gs_acpm"
    "max777x9_contaminant"
    "bc_max77759"
    # Level 3
    "cmupmucal"
    "vh_sched"
    "pixel_metrics"
    # Level 4
    "exynos_pm_qos"
    "exynos-cpupm"
    # USB hardware
    "phy-exynos-usbdrd-eusb-super"
    "dwc3-exynos-usb"
    "xhci-exynos"
    # Type-C port manager
    "tcpci_max77759"
  ];

  # Init script - with diagnostics written to metadata partition
  initScript = writeScript "init" ''
    #!/bin/busybox sh

    /bin/busybox mkdir -p /proc /sys /dev /tmp /config /metadata
    /bin/busybox mount -t proc proc /proc
    /bin/busybox mount -t sysfs sys /sys
    /bin/busybox mount -t devtmpfs dev /dev
    /bin/busybox mount -t tmpfs tmp /tmp
    /bin/busybox mount -t configfs none /config 2>/dev/null
    /bin/busybox --install -s /bin

    # Open watchdog fd
    exec 3>/dev/watchdog 2>/dev/null

    # Diagnostics written to tmpfs, then dd'd to vendor_boot at offset 60MB
    LOG=/tmp/debug.txt
    echo "=== NixOS init started ===" > $LOG 2>/dev/null
    date >> $LOG 2>/dev/null
    echo "=== /dev/block ===" >> $LOG 2>/dev/null
    ls -la /dev/block/platform/13200000.ufs/by-name/ >> $LOG 2>/dev/null
    echo "=== configfs ===" >> $LOG 2>/dev/null
    ls -la /config/ >> $LOG 2>/dev/null
    echo "=== usb_gadget exists? ===" >> $LOG 2>/dev/null
    ls -la /config/usb_gadget/ >> $LOG 2>/dev/null
    echo "=== /sys/class/udc before modules ===" >> $LOG 2>/dev/null
    ls -la /sys/class/udc/ >> $LOG 2>/dev/null

    # Load USB modules in dependency order, logging each
    ${builtins.concatStringsSep "\n" (
      map (mod: ''
        echo "loading ${mod}..." >> $LOG 2>/dev/null
        insmod /lib/modules/${mod}.ko >> $LOG 2>&1
      '') usbModules
    )}

    echo "=== /sys/class/udc after modules ===" >> $LOG 2>/dev/null
    ls -la /sys/class/udc/ >> $LOG 2>/dev/null
    echo "=== usb_gadget after modules ===" >> $LOG 2>/dev/null
    ls -la /config/usb_gadget/ >> $LOG 2>/dev/null
    echo "=== dmesg (last 100 lines) ===" >> $LOG 2>/dev/null
    dmesg | tail -100 >> $LOG 2>/dev/null

    # Wait for UDC
    sleep 3
    echo "=== /sys/class/udc after sleep ===" >> $LOG 2>/dev/null
    ls -la /sys/class/udc/ >> $LOG 2>/dev/null

    # Set up USB gadget serial (ACM)
    if [ -d /config/usb_gadget ]; then
      mkdir -p /config/usb_gadget/g1/strings/0x409
      echo 0x18d1 > /config/usb_gadget/g1/idVendor
      echo 0x4ee7 > /config/usb_gadget/g1/idProduct
      echo "NixOS" > /config/usb_gadget/g1/strings/0x409/manufacturer
      echo "Pixel8" > /config/usb_gadget/g1/strings/0x409/product

      mkdir -p /config/usb_gadget/g1/configs/c.1/strings/0x409
      echo "ACM" > /config/usb_gadget/g1/configs/c.1/strings/0x409/configuration

      mkdir -p /config/usb_gadget/g1/functions/acm.usb0
      ln -s /config/usb_gadget/g1/functions/acm.usb0 /config/usb_gadget/g1/configs/c.1/

      UDC=$(ls /sys/class/udc/ 2>/dev/null | head -1)
      echo "UDC=$UDC" >> $LOG 2>/dev/null
      [ -n "$UDC" ] && echo "$UDC" > /config/usb_gadget/g1/UDC 2>/dev/null
    else
      echo "=== /config/usb_gadget NOT FOUND ===" >> $LOG 2>/dev/null
    fi

    echo "=== gadget setup done ===" >> $LOG 2>/dev/null

    # Also dump block device info for debugging
    echo "=== /proc/partitions ===" >> $LOG 2>/dev/null
    cat /proc/partitions >> $LOG 2>/dev/null
    echo "=== looking for vendor_boot ===" >> $LOG 2>/dev/null

    # Find vendor_boot block device via sysfs partition names
    VB=""
    for part in /sys/class/block/sd*/; do
      pname=$(cat "''${part}uevent" 2>/dev/null | grep PARTNAME | cut -d= -f2)
      devname=$(cat "''${part}uevent" 2>/dev/null | grep DEVNAME | cut -d= -f2)
      if echo "$pname" | grep -q "vendor_boot"; then
        VB="/dev/$devname"
        echo "Found vendor_boot at $VB (partname=$pname)" >> $LOG 2>/dev/null
        break
      fi
    done

    # Write diagnostics to vendor_boot at offset 60MB
    if [ -n "$VB" ] && [ -b "$VB" ]; then
      dd if=$LOG of=$VB bs=1 seek=62914560 conv=notrunc 2>/dev/null
      echo "DIAG_OK" | dd of=$VB bs=1 seek=62914544 conv=notrunc 2>/dev/null
      echo "wrote diagnostics to $VB" >> $LOG 2>/dev/null
    else
      echo "vendor_boot block device not found" >> $LOG 2>/dev/null
    fi
    sync

    # Spawn shell on USB serial as background process
    (
      sleep 2
      while true; do
        if [ -e /dev/ttyGS0 ]; then
          setsid sh -c 'sh </dev/ttyGS0 >/dev/ttyGS0 2>&1'
        fi
        sleep 1
      done
    ) &

    # PID 1 - feed watchdog and stay alive
    while true; do
      echo 1 >&3 2>/dev/null
      sleep 2
    done
  '';

in
stdenvNoCC.mkDerivation {
  name = "pixel8-initramfs";

  dontUnpack = true;

  nativeBuildInputs = [
    cpio
    gzip
  ];

  buildPhase = ''
    mkdir -p root/{bin,dev,proc,sys,tmp,run,config,lib/modules}

    cp ${busybox}/bin/busybox root/bin/busybox
    chmod 755 root/bin/busybox

    cp ${initScript} root/init
    chmod 755 root/init

    # Copy USB modules and dependencies
    ${builtins.concatStringsSep "\n" (
      map (mod: "    cp ${kernel}/modules/${mod}.ko root/lib/modules/") usbModules
    )}

    (cd root && find . | sort | cpio -o -H newc --quiet | gzip -9) > initrd
  '';

  installPhase = ''
    mkdir -p $out
    cp initrd $out/initrd
  '';
}
