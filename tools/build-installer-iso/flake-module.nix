{ self, nixpkgs, clan-core, ... }:
let
  # Shared installer configuration module
  installerModule = { modulesPath, pkgs, ... }: {
    imports = [
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
  };
in
{
  flake = {
    # Export the installer module for reuse
    nixosModules.installer = installerModule;
    
    # Define installer configurations for each architecture
    nixosConfigurations = {
      installer-x86_64-linux = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ installerModule ];
      };
      
      installer-aarch64-linux = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ installerModule ];
      };
    };
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