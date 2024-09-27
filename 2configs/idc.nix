{
  config,
  pkgs,
  lib,
  ...
}:
let
  interdimensional-cable =
    let
      nimaid-github-io = pkgs.fetchFromGitHub {
        owner = "nimaid";
        repo = "nimaid.github.io";
        rev = "5c4f8dda1216d578ad7cd6b0052d5ebf3696ea12";
        sha256 = "sha256-w0u72Q0CkxRu8lr/pp863POzAg09xssbot9pOhSsAn4=";
      };
    in
    pkgs.writeShellScriptBin "interdimensional-cable" ''
      export PATH=${
        lib.makeBinPath [
          pkgs.mpv
          pkgs.jq
          pkgs.gnused
        ]
      }
      mpv --shuffle --playlist=<(jq -r '.videos[]' ${nimaid-github-io}/tv/interdimensional_database.json | sed 's#^#https://youtu.be/#')
    '';
in
{
  systemd.services.reaktor2-idc.serviceConfig.DynamicUser = lib.mkForce false;
  systemd.services.reaktor2-idc.serviceConfig.Group = lib.mkForce "users";

  environment.systemPackages = [ interdimensional-cable ];

  krebs.reaktor2.idc = {
    hostname = "irc.r";
    username = "lass";
    port = "6667";
    nick = "inter_dimensional_cable";
    plugins = [
      {
        plugin = "register";
        config = {
          channels = [
            # "#xxx"
            "#noise"
          ];
        };
      }
      {
        plugin = "system";
        config = {
          hooks.PRIVMSG = [
            {
              activate = "match";
              pattern = ''^!([^ ]+)(?:\s*(.*))?'';
              command = 1;
              arguments = [ 2 ];
              commands = {
                next.filename = pkgs.writeDash "next" ''
                  DISPLAY=:0 ${pkgs.xdotool}/bin/xdotool key "enter"
                '';
                mute.filename = pkgs.writeDash "mute" ''
                  TMUX_TMPDIR=/tmp ${pkgs.tmux}/bin/tmux send-keys -t radio m
                  DISPLAY=:0 ${pkgs.xdotool}/bin/xdotool key "m"
                '';
              };
            }
          ];
        };
      }
    ];
  };
}
