{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 4243;
  stateDir = "/var/lib/kannix";
in
{
  imports = [
    self.inputs.kannix.nixosModules.default
  ];

  services.kannix = {
    enable = true;
    package = self.inputs.kannix.packages.${pkgs.system}.default;
    host = "127.0.0.1";
    inherit port;
    inherit stateDir;
    columns = [
      "Backlog"
      "In Progress"
      "Review"
      "Done"
    ];
    reposDir = "${stateDir}/repos";
    worktreeDir = "${stateDir}/worktrees";
  };

  # SSH access for the kannix user
  users.users.kannix.openssh.authorizedKeys.keys = [
    self.keys.ssh.barnacle.public
    self.keys.ssh.yubi_pgp.public
    self.keys.ssh.yubi1.public
    self.keys.ssh.yubi2.public
    self.keys.ssh.solo2.public
    self.keys.ssh.xerxes.public
    self.keys.ssh.massulus.public
  ];

  services.nginx.virtualHosts."kannix.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };
}
