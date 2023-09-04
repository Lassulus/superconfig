{ config, lib, pkgs, ... }:
let

  bot_port = "7654";
  irc_channel = "#binaergewitter";
in
{
  krebs.reaktor2.bgt-announce = {
    hostname = "irc.libera.chat";
    port = "6697";
    nick = "bgt-announce";
    API.listen = "inet://127.0.0.1:${bot_port}";
    plugins = [
      {
        plugin = "register";
        config = {
          channels = [
            irc_channel
          ];
        };
      }
    ];
  };
  systemd.services.check_bgt_show = {
    startAt = "*:0/5";
    environment = {
      IRC_CHANNEL = irc_channel;
      REAKTOR_PORT = bot_port;
    };
    path = with pkgs; [
      curl
      gnugrep
      jq
    ];
    script = builtins.readFile ./bgt-check.sh;
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "bgt-announce";
      WorkingDirectory = "/var/lib/bgt-announce";
      PrivateTmp = true;
    };
  };
}

