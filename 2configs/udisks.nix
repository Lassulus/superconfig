{ pkgs, ... }:
{
  services.udisks2.enable = true;

  environment.systemPackages = [
    pkgs.udisks2
  ];

  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    btrfs_defaults=discard=async
  '';
}
