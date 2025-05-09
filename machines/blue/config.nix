{ config, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix

    ../../2configs/blue.nix
    ../../2configs/syncthing.nix
  ];

  krebs.build.host = config.krebs.hosts.blue;

  networking.nameservers = [ "1.1.1.1" ];

  time.timeZone = "Europe/Berlin";
  users.users.mainUser.openssh.authorizedKeys.keys = [ config.krebs.users.lass-android.pubkey ];
}
