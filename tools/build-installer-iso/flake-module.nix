{ self, ... }:
let
  # Shared installer configuration module
  installerModule =
    { modulesPath, pkgs, ... }:
    {
      imports = [
        (modulesPath + "/image/images.nix")
      ];

      # Basic installer configuration
      networking.hostName = "installer";

      # Enable emergency access in initrd for debugging
      boot.initrd.systemd.emergencyAccess = true;

      # Enable serial console for VM usage
      boot.kernelParams = [
        "console=ttyS0,115200n8"
        "console=tty0"
      ];

      # Configure systemd for serial console
      systemd.services."serial-getty@ttyS0" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        serviceConfig.Restart = "always";
      };

      # Process installer configuration from ISO during system activation
      system.activationScripts.installer-config = {
        text = ''
          echo "Processing installer configuration from ISO..."

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
              if [ -b "$dev" ] && ${pkgs.util-linux}/bin/lsblk -no FSTYPE "$dev" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q iso9660; then
                ISO_DEVICE="$dev"
                break
              fi
            done
          fi

          if [ -n "$ISO_DEVICE" ]; then
            echo "Found ISO device: $ISO_DEVICE"
            mkdir -p /mnt/iso
            if ${pkgs.util-linux}/bin/mount -t iso9660 -o ro "$ISO_DEVICE" /mnt/iso; then
              echo "Successfully mounted ISO"

              # Check for installer configuration
              if [ -f /mnt/iso/installer-config.json ]; then
                echo "Found installer configuration"
                CONFIG_FILE="/mnt/iso/installer-config.json"

                # Process flake URL if present
                FLAKE_URL=$(${pkgs.jq}/bin/jq -r '.flakeUrl // empty' "$CONFIG_FILE" || true)
                if [ -n "$FLAKE_URL" ]; then
                  echo "Flake URL configured: $FLAKE_URL"
                  # Store for later installation
                  mkdir -p /var/lib
                  echo "$FLAKE_URL" > /var/lib/installer-flake-url
                fi

                # Process files from file structure
                if [ -d /mnt/iso/files ]; then
                  echo "Processing files from file structure..."

                  # Copy all files from the files directory, preserving structure
                  ${pkgs.findutils}/bin/find /mnt/iso/files -type f | while read -r source_file; do
                    # Remove /mnt/iso/files prefix to get target path
                    target_path="''${source_file#/mnt/iso/files}"
                    echo "Copying file: $source_file -> $target_path"

                    # Create target directory
                    mkdir -p "$(dirname "$target_path")"

                    # Copy the file
                    ${pkgs.coreutils}/bin/cp "$source_file" "$target_path"

                    # Apply metadata from JSON if present
                    if ${pkgs.jq}/bin/jq -e ".fileMetadata[\"$target_path\"]" "$CONFIG_FILE" >/dev/null 2>&1; then
                      # Extract metadata for this file
                      OWNER=$(${pkgs.jq}/bin/jq -r ".fileMetadata[\"$target_path\"].owner // \"root:root\"" "$CONFIG_FILE")
                      PERMS=$(${pkgs.jq}/bin/jq -r ".fileMetadata[\"$target_path\"].permissions // \"400\"" "$CONFIG_FILE")

                      echo "Setting owner: $OWNER, permissions: $PERMS for $target_path"
                      ${pkgs.coreutils}/bin/chown "$OWNER" "$target_path" || echo "Warning: failed to set owner $OWNER"
                      ${pkgs.coreutils}/bin/chmod "$PERMS" "$target_path" || echo "Warning: failed to set permissions $PERMS"
                    else
                      # Apply defaults: root:root, 400
                      echo "Applying default metadata for $target_path"
                      ${pkgs.coreutils}/bin/chown root:root "$target_path" || echo "Warning: failed to set default owner"
                      ${pkgs.coreutils}/bin/chmod 400 "$target_path" || echo "Warning: failed to set default permissions"
                    fi
                  done
                fi

              else
                echo "No installer configuration found in ISO"
              fi

              ${pkgs.util-linux}/bin/umount /mnt/iso
            else
              echo "Failed to mount ISO device $ISO_DEVICE"
            fi
          else
            echo "No ISO device found"
          fi
        '';
        deps = [ ];
      };

      # Service to install from flake URL if configured
      systemd.services.installer-flake-install = {
        description = "Install NixOS from configured flake URL";
        wantedBy = [ "multi-user.target" ];
        after = [
          "installer-config.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        path = with pkgs; [
          git
          nix
          coreutils
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          if [ -f /var/lib/installer-flake-url ]; then
            FLAKE_URL=$(cat /var/lib/installer-flake-url)
            echo "Installing from flake: $FLAKE_URL"

            # TODO: Add actual installation logic here
            # This would typically involve:
            # 1. Partitioning disks
            # 2. Mounting filesystems
            # 3. Running nixos-install with the flake
            echo "Installation from flake not yet implemented"
            echo "Flake URL: $FLAKE_URL"
          else
            echo "No flake URL configured for automatic installation"
          fi
        '';
      };
    };
in
{
  flake = {
    # Export the installer module for reuse
    nixosModules.installer = installerModule;
  };

  perSystem =
    { pkgs, ... }:
    {
      packages.build-installer-iso = pkgs.writeShellApplication {
        name = "build-installer-iso";
        runtimeInputs = with pkgs; [
          xorriso
          coreutils
          nix
        ];
        text = ''
          # Export flake root for the script to use
          export FLAKE_ROOT="${self}"
          ${builtins.readFile ./build-installer-iso.sh}
        '';
      };
    };
}
