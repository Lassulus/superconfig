{ config, lib, pkgs, ... }:

{
  services.bitlbee = {
    enable = true;
    portNumber = 6666;
    plugins = [
      pkgs.bitlbee-facebook
      pkgs.bitlbee-steam
      pkgs.bitlbee-discord
    ];
    libpurple_plugins = [
      # pkgs.telegram-purple
      # pkgs.tdlib-purple
      # pkgs.purple-gowhatsapp
    ];
    configDir = "/var/state/bitlbee";
  };

  systemd.services.bitlbee.serviceConfig = {
    ExecStartPre = [
      "+${pkgs.writeDash "setup-bitlbee" ''
        ${pkgs.coreutils}/bin/chown bitlbee:bitlbee /var/state/bitlbee || :
      ''}"
    ];
    ReadWritePaths = [
      "/var/state/bitlbee"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /var/state/bitlbee 0700 - - -"
  ];
}
