{ lib, ... }:
{
  nix.settings.experimental-features = [
    # for container in builds support
    "auto-allocate-uids"
    "cgroups"
  ];

  # no longer need to pre-allocate build users for everything
  nix.settings.auto-allocate-uids = true;

  # for container in builds support
  nix.settings.system-features = lib.mkDefault [ "uid-range" ];
}
