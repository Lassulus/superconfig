{ config, pkgs, ... }:

let
  hooks = pkgs.reaktor2-plugins.hooks;
in
{
  krebs.reaktor2.coders = {
    hostname = "irc.hackint.org";
    port = "9999";
    useTLS = true;
    nick = "reaktor2|lass";
    plugins = [
      {
        plugin = "register";
        config = {
          channels = [
            "#coders"
            "#germany"
            "#panthermoderns"
          ];
        };
      }
      {
        plugin = "system";
        config = {
          workdir = config.krebs.reaktor2.coders.stateDir;
          hooks.PRIVMSG = [
            hooks.sed
            hooks.url-title
            {
              activate = "match";
              pattern = ''^!([^ ]+)(?:\s*(.*))?'';
              command = 1;
              arguments = [ 2 ];
              commands = {
                ping.filename = pkgs.writeDash "ping" ''
                  exec /run/wrappers/bin/ping -q -c1 "$1" 2>&1 | tail -1
                '';
                google.filename = pkgs.writeDash "google" ''
                  exec ${pkgs.ddgr}/bin/ddgr -C -n1 --json "$@" | \
                    ${pkgs.jq}/bin/jq '@text "\(.[0].abstract) \(.[0].url)"'
                '';
                shrug.filename = pkgs.writeDash "shrug" ''
                  exec echo '¯\_(ツ)_/¯'
                '';
                table.filename = pkgs.writeDash "table" ''
                  exec echo '(╯°□°）╯ ┻━┻'
                '';
              };
            }
          ];
        };
      }
    ];
  };
}
