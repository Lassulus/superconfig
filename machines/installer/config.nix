{ modulesPath, pkgs, ... }:

{
  imports = [
    # ../../2configs/installer-tor.nix
    (modulesPath + "/image/images.nix")

  ];

  # Basic installer configuration
  networking.hostName = "installer";

  # Enable emergency access in initrd for debugging
  boot.initrd.systemd.emergencyAccess = true;

  # Enable serial console for VM usage
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];
  
  # Configure systemd for serial console
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    serviceConfig.Restart = "always";
  };

  # Auto-mount ISO and extract vars
  systemd.services.extract-vars = {
    description = "Extract vars from ISO";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    path = with pkgs; [ util-linux coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euxo pipefail

      # Find the ISO device (usually sr0, but could be others)
      ISO_DEVICE=""
      for dev in /dev/sr*; do
        if [ -b "$dev" ]; then
          ISO_DEVICE="$dev"
          break
        fi
      done

      if [ -z "$ISO_DEVICE" ]; then
        echo "No ISO device found, checking loop devices..."
        for dev in /dev/loop*; do
          if [ -b "$dev" ] && lsblk -no FSTYPE "$dev" 2>/dev/null | grep -q iso9660; then
            ISO_DEVICE="$dev"
            break
          fi
        done
      fi

      if [ -n "$ISO_DEVICE" ]; then
        echo "Found ISO device: $ISO_DEVICE"
        mkdir -p /mnt/iso
        if mount -t iso9660 -o ro "$ISO_DEVICE" /mnt/iso; then
          echo "Successfully mounted ISO"
          if [ -d /mnt/iso/vars ]; then
            echo "Extracting vars to /vars"
            cp -r /mnt/iso/vars /vars
            chmod -R u+w /vars
            echo "Vars extracted successfully"
          else
            echo "No vars directory found in ISO"
          fi
        else
          echo "Failed to mount ISO device $ISO_DEVICE"
        fi
      else
        echo "No ISO device found"
      fi
    '';
  };
}
