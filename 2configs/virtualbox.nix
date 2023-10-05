{ config, pkgs, ... }:

let
  mainUser = config.users.extraUsers.mainUser;

in {
  #services.virtualboxHost.enable = true;
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableHardening = false;

  users.extraUsers = {
    virtual = {
      name = "virtual";
      description = "user for running VirtualBox";
      home = "/home/virtual";
      useDefaultShell = true;
      extraGroups = [ "vboxusers" "audio" "video" ];
      createHome = true;
    };
  };
  security.sudo.extraConfig = ''
    ${mainUser.name} ALL=(virtual) NOPASSWD: ALL
  '';
}
