{ lib, ... }:
with lib;
{
  security.chromiumSuidSandbox.enable = true;
  security.lockKernelModules = false;
  boot.kernel.sysctl."user.max_user_namespaces" = 63414;

  imports = [
    <nixpkgs/nixos/modules/profiles/hardened.nix>
  ];
}
