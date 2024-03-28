{
  imports = [
    ../../2configs
  ];

  krebs.build.host.name = "virtulus";
  services.mingetty.autologinUser = "lass";
}
