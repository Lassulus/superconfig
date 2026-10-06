{ modulesPath, lib, ... }:
{
  system.stateVersion = lib.mkForce "25.05";
  imports = [
    ../../configs
    ../../configs/spora.nix
    (modulesPath + "/image/images.nix")
  ];

  services.getty.autologinUser = "demo";

  users.users.demo = {
    isNormalUser = true;
    password = "clanlol";
  };

  services.tor.enable = true;
}
