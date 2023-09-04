{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.radio = {
    sshKey = "${config.krebs.secret.directory}/radio.sync.key";
  };
  containers.radio = {
    bindMounts."/var/music" = {
      hostPath = "/var/music";
      isReadOnly = false;
    };
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 8000"; target = "ACCEPT"; }
  ];
  krebs.htgen.radio-redirect = {
    port = 8000;
    scriptFile = pkgs.writers.writeDash "redir" ''
      printf 'HTTP/1.1 301 Moved Permanently\r\n'
      printf "Location: http://radio.lassul.us''${Request_URI}\r\n"
      printf '\r\n'
    '';
  };
}
