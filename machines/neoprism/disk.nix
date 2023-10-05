{ lib, ... }:
{
  disk = (lib.genAttrs [ "/dev/nvme0n1" "/dev/nvme1n1" ] (disk: {
    type = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
        };
        ESP = {
          size = "1G";
          content = {
            type = "mdraid";
            name = "boot";
          };
        };
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
      };
    };
  })) // {
    hdd1 = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "zfs";
        pool = "tank";
      };
    };
  };
  mdadm = {
    boot = {
      type = "mdadm";
      level = 1;
      metadata = "1.0";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    };
  };
  zpool = {
    zroot = {
      type = "zpool";
      mode = "mirror";
      mountpoint = "/";
      rootFsOptions = {
      };
      datasets.reserved = {
        type = "zfs_fs";
        options.refreservation = "1G";
      };
    };
    tank = {
      type = "zpool";
      datasets = {
        reserved = {
          type = "zfs_fs";
          options.refreservation = "1G";
        };
        containers = {
          type = "zfs_fs";
          mountpoint = "/var/lib/containers";
          options = {
            canmount = "noauto";
          };
        };
        home = {
          type = "zfs_fs";
          mountpoint = "/home";
          options = {
            canmount = "noauto";
          };
        };
        srv = {
          type = "zfs_fs";
          mountpoint = "/srv";
          options = {
            canmount = "noauto";
          };
        };
        libvirt = {
          type = "zfs_fs";
          mountpoint = "/var/lib/libvirt";
          options = {
            canmount = "noauto";
          };
        };
        # encrypted = {
        #   type = "zfs_fs";
        #   options = {
        #     canmount = "noauto";
        #     mountpoint = "none";
        #     encryption = "aes-256-gcm";
        #     keyformat = "passphrase";
        #     keylocation = "prompt";
        #   };
        # };
        # "encrypted/download" = {
        #   type = "zfs_fs";
        #   mountpoint = "/var/download";
        #   options = {
        #     canmount = "noauto";
        #   };
        # };
      };
    };
  };
}
