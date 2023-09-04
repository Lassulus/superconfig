{ self, ... }:
{
  imports = [
    self.inputs.disko.nixosModules.disko
  ];
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            name = "boot";
            start = "0";
            end = "1M";
            part-type = "primary";
            flags = ["bios_grub"];
          }
          {
            name = "ESP";
            start = "1MiB";
            end = "1GiB";
            fs-type = "fat32";
            bootable = true;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          }
          {
            name = "root";
            start = "1GiB";
            end = "100%";
            content = {
              type = "luks";
              name = "aergia1";
              content = {
                type = "btrfs";
                extraArgs = "-f"; # Override existing partition
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # Mountpoints inferred from subvolume name
                  "/home" = {
                    mountOptions = [];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = [];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          }
        ];
      };
    };
  };
}

