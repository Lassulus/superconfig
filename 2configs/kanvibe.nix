{
  self,
  config,
  pkgs,
  ...
}:
let
  kanvibe = self.packages.${pkgs.system}.kanvibe;
  port = 4242;
in
{
  users.users.kanban = {
    isNormalUser = true;
    home = "/var/lib/kanvibe";
    createHome = true;
    group = "users";
    openssh.authorizedKeys.keys = [
      self.keys.ssh.barnacle.public
      self.keys.ssh.yubi_pgp.public
      self.keys.ssh.yubi1.public
      self.keys.ssh.yubi2.public
      self.keys.ssh.solo2.public
      self.keys.ssh.xerxes.public
      self.keys.ssh.massulus.public
    ];
  };

  clan.core.vars.generators.vibe-kanban = {
    files."htpasswd" = {
      owner = "root";
      group = "nginx";
      mode = "0640";
    };
    files."password" = {
      owner = "kanban";
      group = "kanban";
      mode = "0400";
    };
    runtimeInputs = with pkgs; [
      apacheHttpd
      coreutils
    ];
    script = ''
      password=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 24)
      echo "$password" > "$out/password"
      htpasswd -nbB kanban "$password" > "$out/htpasswd"
    '';
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "kanban" ];
    ensureUsers = [
      {
        name = "kanban";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.kanvibe = {
    description = "KanVibe AI Agent Kanban Board";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.service" ];

    path = with pkgs; [
      tmux
      git
      openssh
      nodejs
      bash
      coreutils
      nix
    ];

    environment = {
      PORT = toString port;
      NODE_ENV = "production";
      KANVIBE_USER = "kanban";
    };

    serviceConfig = {
      Type = "simple";
      LoadCredential = "password:${config.clan.core.vars.generators.vibe-kanban.files."password".path}";
      ExecStart =
        let
          startScript = pkgs.writeShellScript "kanvibe-start" ''
            export KANVIBE_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/password")"
            export DATABASE_URL="postgresql:///kanban?host=/run/postgresql"

            # Run TypeORM migrations
            cd ${kanvibe}/lib/kanvibe
            ${pkgs.nodejs}/bin/node -e "
              require('tsx/cjs');
              const ds = require('./src/lib/typeorm-cli.config.ts').default;
              ds.initialize().then(d => d.runMigrations()).then(() => { console.log('Migrations done'); process.exit(0); }).catch(e => { console.error(e); process.exit(1); });
            "

            exec ${kanvibe}/bin/kanvibe
          '';
        in
        toString startScript;
      Restart = "on-failure";
      RestartSec = 10;
      User = "kanban";
      Group = "users";
      WorkingDirectory = "/var/lib/kanvibe";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ "/var/lib/kanvibe" ];
      PrivateTmp = true;
    };
  };

  services.nginx.virtualHosts."kanban.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        auth_basic "Kanban";
        auth_basic_user_file ${config.clan.core.vars.generators.vibe-kanban.files."htpasswd".path};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
    locations."/api/terminal/" = {
      proxyPass = "http://127.0.0.1:${toString (port - 1)}";
      proxyWebsockets = true;
      extraConfig = ''
        auth_basic "Kanban";
        auth_basic_user_file ${config.clan.core.vars.generators.vibe-kanban.files."htpasswd".path};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
    locations."/api/board/" = {
      proxyPass = "http://127.0.0.1:${toString (port - 1)}";
      proxyWebsockets = true;
      extraConfig = ''
        auth_basic "Kanban";
        auth_basic_user_file ${config.clan.core.vars.generators.vibe-kanban.files."htpasswd".path};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
