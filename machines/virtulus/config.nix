{ modulesPath, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/spora.nix
    (modulesPath + "/image/images.nix")
  ];

  krebs.build.host.name = "virtulus";
  services.mingetty.autologinUser = "demo";

  users.users.demo = {
    isNormalUser = true;
    password = "clanlol";
  };

  services.tor.enable = true;
}
