{ config, lib, pkgs, ... }: let

  weechat-configured = pkgs.weechat-declarative.override {
    config = {
      scripts = [
        pkgs.weechatScripts.weechat-matrix
        pkgs.weechatScripts.wee-slack
      ];
      settings = {
        irc.server_default.nicks = [ "lassulus" "hackulus" ];
        irc.server.bitlbee = {
          addresses = "localhost/6666";
          command = "msg &bitlbee identify \${sec.data.bitlbee}";
        };
        irc.server.hackint = {
          addresses = "irc.hackint.org/6697";
          autojoin = [
            "#c3-gsm"
            "#panthermoderns"
            "#feldoffice"
            "#36c3"
            "#cccac"
            "#nixos"
            "#krebs"
            "#krebstel"
            "#c-base"
            "#afra"
            "#tvl"
            "#tvix-dev"
            "#eloop"
            "#systemdultras"
            "#rc3"
            "#krebs-announce"
            "#the_playlist"
            "#germany"
            "#hackint"
            "#dezentrale"
            "#hackerfleet \${sec.data.c3-gsm}" # TODO support channel passwords in a cooler way
          ];
          ssl = true;
          sasl_fail = "reconnect";
          sasl_username = "lassulus";
          sasl_password = "\${sec.data.hackint_sasl}";
        };
        irc.server.r = {
          addresses = "irc.r";
          autojoin = [
            "#xxx"
            "#autowifi"
            "#brockman"
            "#flix"
            "#kollkoll"
            "#noise"
            "#mukke"
          ];
          sasl_fail = "reconnect";
          sasl_username = "lassulus";
          sasl_password = "\${sec.data.r_sasl}";
          anti_flood_prio_high = 0;
          anti_flood_prio_low = 0;
        };
        irc.server.libera = {
          addresses = "irc.libera.chat/6697";
          autojoin = [
            "#shackspace"
            "#nixos"
            "#krebs"
            "#dezentrale"
            "#tinc"
            "#nixos-de"
            "#fysi"
            "#hillhacks"
            "#nixos-rc3"
            "#binaergewitter"
            "#hackerfleet"
            "#weechat"
          ];
          ssl = true;
          sasl_username = "lassulus";
          sasl_fail = "reconnect";
          sasl_password = "\${sec.data.libera_sasl}";
        };
        irc.server.news = {
          addresses = "news.r";
          autojoin = [
            "#all"
            "#aluhut"
            "#querdenkos"
            "#news"
            "#drachengame"
          ];
          anti_flood_prio_high = 0;
          anti_flood_prio_low = 0;
        };
        matrix.server.lassulus = {
          address = "matrix.lassul.us";
          username = "lassulus";
          password = "\${sec.data.matrix_lassulus}";
          device_name = config.networking.hostName;
        };
        plugins.var.python.go.short_name = true;
        plugins.var.python.go.short_name_server = true;
        plugins.var.python.go.fuzzy_search = true;
        relay.network.password = "xxx"; # secret?
        relay.port.weechat = 9998;
        relay.weechat.commands = "*,!exec,!quit";
        weechat.look.buffer_time_format = "%m-%d_%H:%M:%S";
        weechat.look.item_time_format = "%m-%d_%H:%M:%S";
        irc.look.color_nicks_in_names = true;
        irc.look.color_nicks_in_nicklist = true;
        logger.file.mask = "$plugin.$name/%Y-%m-%d.weechatlog";
        logger.file.path = "/var/state/weechat_logs";
        logger.look.backlog = 1000;
        weechat.notify.irc.news."#all" = "highlight";

        # setting logger levels for channels is currently not possible declarativly
        # because of already defined
        logger.level.core.weechat = 0;
        logger.level.irc = 3;
        logger.level.python = 3;
        weechat.bar.title.color_bg = 0;
        weechat.bar.status.color_bg = 0;
        alias.cmd.reload = "exec -oc cat /etc/weechat.set";
        script.scripts.download_enabled = true;
        weechat.look.prefix_align = "left";
        weechat.look.prefix_align_max = 20;
        irc.look.server_buffer = "independent";
        matrix.look.server_buffer = "independent";
        weechat.bar.buflist.size_max = 20;
        weechat.color.chat_nick_colors = [
          1 2 3 4 5 6 9
          10 11 12 13 14
          28 29
          30 31 32 33 34 35 36 37 38 39
          70
          94
          101 102 103 104 105 106 107
          130 131 133 134 135 136 137
          140 141 142 143
          160 161 162 163 165 166 167 168 169
          170 171 172 173 174 175
          196 197 198 199
          200 201 202 203 204 205 206 208 209 209
          210 211 212
        ];
      };
      extraCommands = ''
        /script upgrade
        /script install go.py
        /script install nickregain.pl
        /script install autosort.py
        /key bind meta-q /go
        /key bind meta-t /bar toggle nicklist
        /key bind meta-y /bar toggle buflist
        /filter addreplace irc_smart * irc_smart_filter *
        /filter addreplace playlist_topic irc.*.#the_playlist irc_topic *
        /filter addreplace xxx_joinpart irc.r.#xxx irc_join,irc_part,irc_quit *
        /set logger.level.irc.news 0
        /set logger.level.python.server.nixos_dev = 0;
        /set logger.level.irc.hackint.#the_playlist = 0;
        /connect bitlbee
        /connect r
        /connect news
        /connect libera
        /connect hackint
        /matrix connect nixos_dev
        /matrix connect lassulus
      '';
      files."sec.conf" = toString (pkgs.writeText "sec.conf" ''
        [crypt]
        cipher = aes256
        hash_algo = sha256
        passphrase_command = "cat $CREDENTIALS_DIRECTORY/WEECHAT_PASSPHRASE"
        salt = on

        [data]
        __passphrase__ = on
        hackint_sasl = "5CA242E92E7A09B180711B50C4AE2E65C42934EB4E584EC82BC1281D8C72CD411D590C16CC435687C0DA13759873CC"
        libera_sasl = "9500B5AC3B29F9CAA273F1B89DC99550E038AF95C4B47442B1FB4CB9F0D6B86B26015988AD39E642CA9C4A78DED7F42D1F409B268C93E778"
        r_sasl = "CB6FB1421ED5A9094CD2C05462DB1FA87C4A675628ABD9AEC9928A1A6F3F96C07D9F26472331BAF80B7B73270680EB1BBEFD"
        c3-gsm = "C49DD845900CFDFA93EEBCE4F1ABF4A963EF6082B7DA6410FA701CC77A04BB6C201FCB864988C4F2B97ED7D44D5A28F162"
        bitlbee = "814ECAC59D9CF6E8340B566563E5D7E92AB92209B49C1EDE4CAAC32DD0DF1EC511D97C75E840C45D69BB9E3D03E79C"
        matrix_lassulus = "0CA5C0F70A9F893881370F4A665B4CC40FBB1A41E53BC94916CD92B029103528611EC0B390116BE60FA79AE10F486E96E17B0824BE2DE1C97D87B88F5407330DAD70C044147533C36B09B7030CAD97"
      '');
    };
  };

in {
  users.users.mainUser.packages = [
    weechat-configured
  ];
  environment.etc."weechat.set".source = "${weechat-configured}/weechat.set";
  systemd.tmpfiles.rules = [
    "d /var/state/weechat_logs 0700 lass users -"
    "d /var/state/weechat 0700 lass users -"
    "d /var/state/weechat_cfg 0700 lass users -"
    "L+ /home/lass/.local/share/weechat - - - - ../../../../var/state/weechat"
    "L+ /home/lass/.config/weechat - - - - ../../../../var/state/weechat_cfg"
  ];

  systemd.services.weechat = {
    wantedBy = [ "multi-user.target" ];
    restartIfChanged = false;
    serviceConfig = {
      User = "lass";
      RemainAfterExit = true;
      Type = "oneshot";
      LoadCredential = [
        "WEECHAT_PASSPHRASE:${config.krebs.secret.directory}/weechat_passphrase"
      ];
      ExecStart = "${pkgs.tmux}/bin/tmux -2 new-session -d -s IM ${weechat-configured}/bin/weechat";
      ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t IM"; # TODO run save in weechat
    };
  };
}
