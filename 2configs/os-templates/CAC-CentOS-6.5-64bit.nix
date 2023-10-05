_:

{
  boot.loader.grub = {
    device = "/dev/sda";
    splashImage = null;
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "vmw_pvscsi"
  ];

  fileSystems."/" = {
    device = "/dev/VolGroup/lv_root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/VolGroup/lv_swap"; }
  ];

  users.extraGroups = {
    # ● systemd-tmpfiles-setup.service - Create Volatile Files and Directories
    #    Loaded: loaded (/nix/store/2l33gg7nmncqkpysq9f5fxyhlw6ncm2j-systemd-217/example/systemd/system/systemd-tmpfiles-setup.service)
    #    Active: failed (Result: exit-code) since Mon 2015-03-16 10:29:18 UTC; 4s ago
    #      Docs: man:tmpfiles.d(5)
    #            man:systemd-tmpfiles(8)
    #   Process: 19272 ExecStart=/nix/store/2l33gg7nmncqkpysq9f5fxyhlw6ncm2j-systemd-217/bin/systemd-tmpfiles --create --remove --boot --exclude-prefix=/dev (code=exited, status=1/FAILURE)
    #  Main PID: 19272 (code=exited, status=1/FAILURE)
    #
    # Mar 16 10:29:17 cd systemd-tmpfiles[19272]: [/usr/lib/tmpfiles.d/legacy.conf:26] Unknown group 'lock'.
    # Mar 16 10:29:18 cd systemd-tmpfiles[19272]: Two or more conflicting lines for /var/log/journal configured, ignoring.
    # Mar 16 10:29:18 cd systemd-tmpfiles[19272]: Two or more conflicting lines for /var/log/journal/7b35116927d74ea58785e00b47ac0f0d configured, ignoring.
    # Mar 16 10:29:18 cd systemd[1]: systemd-tmpfiles-setup.service: main process exited, code=exited, status=1/FAILURE
    # Mar 16 10:29:18 cd systemd[1]: Failed to start Create Volatile Files and Directories.
    # Mar 16 10:29:18 cd systemd[1]: Unit systemd-tmpfiles-setup.service entered failed state.
    # Mar 16 10:29:18 cd systemd[1]: systemd-tmpfiles-setup.service failed.
    # warning: error(s) occured while switching to the new configuration
    lock.gid = 10001;
  };
}
