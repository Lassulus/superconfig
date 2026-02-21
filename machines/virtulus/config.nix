{ modulesPath, lib, ... }:
{
  system.stateVersion = lib.mkForce "25.05";
  imports = [
    ../../2configs
    ../../2configs/spora.nix
    (modulesPath + "/image/images.nix")
  ];

  krebs.build.host.name = "virtulus";
  services.getty.autologinUser = "demo";

  users.users.demo = {
    isNormalUser = true;
    password = "clanlol";
  };

  services.tor.enable = true;
}
