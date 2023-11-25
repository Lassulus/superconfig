{ self, config, pkgs, ... }:
{
  imports = [
    self.inputs.stockholm.nixosModules.htgen
  ];
  krebs.sync-containers3.containers.radio = {
    sshKey = "${config.krebs.secret.directory}/radio.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#radio switch --no-write-lock-file
    '';
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
