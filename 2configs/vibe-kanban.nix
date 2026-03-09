{
  self,
  config,
  pkgs,
  ...
}:
let
  vibe-kanban-base = self.inputs.llm-agents.packages.${pkgs.system}.vibe-kanban;
  # HACK: binary-patch pinned claude-code version for claude 4.6 support
  # TODO: fork upstream and bump properly, then submit PR
  vibe-kanban = vibe-kanban-base.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ${pkgs.gnused}/bin/sed -i 's|@anthropic-ai/claude-code@2\.1\.45|@anthropic-ai/claude-code@2.1.71|g' $out/bin/vibe-kanban
    '';
  });
  port = 4242;
in
{
  users.users.kanban = {
    isNormalUser = true;
    home = "/var/lib/vibe-kanban";
    createHome = true;
    group = "users";
    useDefaultShell = true;
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
    files."password" = { };
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

  systemd.services.vibe-kanban = {
    description = "Vibe Kanban Board";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [
      pkgs.nodejs
      pkgs.git
      pkgs.bash
      pkgs.coreutils
      pkgs.nix
    ];

    environment = {
      HOST = "127.0.0.1";
      PORT = toString port;
    };

    serviceConfig = {
      ExecStart = "${vibe-kanban}/bin/vibe-kanban";
      Restart = "on-failure";
      RestartSec = 10;
      User = "kanban";
      Group = "users";
      WorkingDirectory = "/var/lib/vibe-kanban";
    };
  };

  services.nginx.virtualHosts."kanban.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        auth_basic "Vibe Kanban";
        auth_basic_user_file ${config.clan.core.vars.generators.vibe-kanban.files."htpasswd".path};
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
