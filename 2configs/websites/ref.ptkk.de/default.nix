{ config, lib, pkgs, ... }:
{
  services.nginx.virtualHosts."ref.ptkk.de" = {
    enableACME = true;
    locations."/" = {
      proxyPass = "http://localhost:4626";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Upgrade $http_upgrade;
        proxy_cache_bypass $http_upgrade;
      '';
    };
    locations."/static/" = {
      alias = "/var/lib/ref.ptkk.de/static/";
    };
    forceSSL = true;
  };
  systemd.services."ref.ptkk.de" = {
    wantedBy = [ "multi-user.target" ];
    environment = {
      PRODUCTION = "yip";
      DATA_DIR = "/var/lib/ref.ptkk.de/data";
      PORT = "4626";
      STATIC_ROOT = "/var/lib/ref.ptkk.de/static";
    };
    path = with pkgs; [
      git
      gnutar
      gzip
      nix
    ];
    serviceConfig = {
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/ref.ptkk.de/data"
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/ref.ptkk.de/code"
        "${pkgs.coreutils}/bin/mkdir -p /var/lib/ref.ptkk.de/static"
      ];
      ExecStart = pkgs.writers.writeDash "nixify" ''
        cd code
        if test -e shell.nix; then
          ${pkgs.nix}/bin/nix-shell -I /var/src --run serve
        else
          echo 'no shell.nix, bailing out'
          exit 0
        fi
      '';
      LoadCredential = [
        "django-secret.key:${config.krebs.secret.directory}/ref.ptkk.de-django.key"
      ];
      User = "ref.ptkk.de";
      WorkingDirectory = "/var/lib/ref.ptkk.de";
      StateDirectory = "ref.ptkk.de";
      Restart = "always";
      RestartSec = "100s";
    };
  };
  systemd.services."ref.ptkk.de-restarter" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart ref.ptkk.de.service";
    };
  };
  systemd.paths."ref.ptkk.de-restarter" = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = [
      "/var/lib/ref.ptkk.de/code"
      "/var/src/nixpkgs"
    ];
  };

  users.users."ref.ptkk.de" = {
    isSystemUser = true;
    uid = pkgs.stockholm.lib.genid_uint31 "ref.ptkk.de";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF6fu6LtyRdk++qIBpP0BdZQHSTqzNNlvp7ML2Dv0IxD CI@github.com"
      config.krebs.users.lass.pubkey
    ];
    group = "nginx";
    home = "/var/lib/ref.ptkk.de";
    useDefaultShell = true;
  };
}
