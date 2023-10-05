{ config, lib, pkgs, ... }: let
  weechat = pkgs.weechat.override {
    configure = { availablePlugins, ... }: {
      scripts = with pkgs.weechatScripts; [
        weechat-matrix
      ];
    };
  };

  tmux = "/run/current-system/sw/bin/tmux";

in {
  imports = [
    ./bitlbee.nix
  ];
  environment.systemPackages = [ weechat ];
  systemd.services.chat = {
    description = "chat environment setup";
    environment.WEECHAT_HOME = "\$HOME/.weechat";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    restartIfChanged = false;

    path = [
      pkgs.rxvt-unicode-unwrapped.terminfo
    ];

    serviceConfig = {
      User = "lass";
      RemainAfterExit = true;
      Type = "oneshot";
      ExecStart = "${tmux} -2 new-session -d -s IM ${weechat}/bin/weechat";
      ExecStop = "${tmux} kill-session -t IM"; # TODO run save in weechat
    };
  };
}
