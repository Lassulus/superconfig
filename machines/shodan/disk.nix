{ self, ... }:
{
  imports = [
    self.inputs.disko.nixosModules.disko
  ];
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNX0H662201F";
      content = {
        type = "gpt";
        partitions = {
          grub = {
            size = "1M";
            type = "EF02";
          };
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "luks";
              name = "shodan";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # Mountpoints inferred from subvolume name
                  "/home" = {
                    mountOptions = [ ];
                    mountpoint = "/home";
                  };
                  "/nix" = {
                    mountOptions = [ ];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
