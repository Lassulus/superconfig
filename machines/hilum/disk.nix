{ ... }:
{
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/disk/by-id/usb-Kingston_DataTraveler_Max_BFB8357EA7B1718B0070-0:0";
      content = {
        type = "gpt";
        partitions = {
          MBR = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };
          DATA = {
            size = "100G";
            type = "8300"; # not sure if correct type
            priority = 2;
            content = {
              type = "filesystem";
              format = "exfat";
            };
          };
          boot = {
            size = "25G";
            type = "EF00";
            priority = 3;
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            priority = 4;
            content = {
              type = "luks";
              name = "hilum";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
