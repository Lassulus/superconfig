{
  fileSystems."/mnt/prism" = {
    device = "prism.w:/export/download";
    fsType = "nfs";
    options = [
      #"timeo=14"
      "noauto"
      "noatime"
      "nodiratime"
      #"noac"
      #"nocto"
      "x-systemd.automount"
      "x-systemd.device-timeout=1"
      "x-systemd.idle-timeout=1min"
      "x-systemd.requires=retiolum.service"
      "user"
      "_netdev"
      "soft"
    ];
  };
}

