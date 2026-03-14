{
  self,
  pkgs,
  lib,
  ...
}:
let
  port = 4243;
  stateDir = "/var/lib/kannix";
  bareRepo = "${stateDir}/repos/kannix.git";
  srcDir = "${stateDir}/checkout/kannix";

  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      fastapi
      uvicorn
      jinja2
      python-multipart
      bcrypt
      websockets
    ]
  );

  configFile = pkgs.writeText "kannix.json" (
    builtins.toJSON {
      columns = [
        "backlog"
        "planning"
        "doing"
        "review"
        "done"
      ];
      server = {
        host = "127.0.0.1";
        inherit port;
      };
      repos_dir = "${stateDir}/repos";
      worktree_dir = "${stateDir}/worktrees";
    }
  );

  vendorDir = pkgs.runCommand "kannix-vendor" { } ''
    mkdir -p $out
    cp ${pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/npm/diff2html@3.4.56/bundles/css/diff2html.min.css";
      hash = "sha256-0+zA6bKx5chGbBneKb7QUv0IY0ddJYKezIWERu/e03I=";
    }} $out/diff2html.min.css
    cp ${pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/npm/diff2html@3.4.56/bundles/js/diff2html-ui.min.js";
      hash = "sha256-mXoOqduEwKvM41xkFZr+RtMNz9/SQ0FWGdmz6BAXE4s=";
    }} $out/diff2html-ui.min.js
  '';

  kannixDevScript = pkgs.writeShellScript "kannix-dev" ''
    export KANNIX_CONFIG=${configFile}
    export KANNIX_STATE_DIR=${stateDir}
    export PYTHONPATH=${srcDir}/src
    export PATH=${
      lib.makeBinPath [
        pkgs.tmux
        pkgs.git
      ]
    }:$PATH
    cd ${srcDir}

    # Symlink vendor files
    mkdir -p src/kannix/static/vendor
    ln -sf ${vendorDir}/diff2html.min.css src/kannix/static/vendor/diff2html.min.css
    ln -sf ${vendorDir}/diff2html-ui.min.js src/kannix/static/vendor/diff2html-ui.min.js

    exec ${pythonEnv}/bin/python -m uvicorn \
      kannix.main:create_dev_app \
      --factory \
      --host 127.0.0.1 \
      --port ${toString port} \
      --reload \
      --reload-dir ${srcDir}/src
  '';
in
{
  users.users.kannix = {
    isNormalUser = true;
    home = stateDir;
    createHome = true;
    group = "users";
    shell = pkgs.bashInteractive;
    linger = true;
    openssh.authorizedKeys.keys = [
      self.keys.ssh.barnacle.public
      self.keys.ssh.yubi_pgp.public
      self.keys.ssh.yubi1.public
      self.keys.ssh.yubi2.public
      self.keys.ssh.solo2.public
      self.keys.ssh.xerxes.public
      self.keys.ssh.massulus.public
    ];
    packages = [
      pythonEnv
      pkgs.tmux
      pkgs.git
      self.packages.${pkgs.system}.s
      (pkgs.writeShellScriptBin "kannix-ctl" ''
        export PYTHONPATH=${srcDir}/src
        exec ${pythonEnv}/bin/python -m kannix.ctl "$@"
      '')
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir}/repos 0755 kannix users -"
    "d ${stateDir}/worktrees 0755 kannix users -"
    "d ${stateDir}/checkout 0755 kannix users -"
  ];

  systemd.services.kannix-checkout = {
    description = "Create kannix worktree from bare repo";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!${srcDir}/.git";
    serviceConfig = {
      Type = "oneshot";
      User = "kannix";
      Group = "users";
      ExecStart = toString (
        pkgs.writeShellScript "kannix-checkout" ''
          ${pkgs.git}/bin/git --git-dir=${bareRepo} worktree add ${srcDir} main
        ''
      );
    };
  };

  systemd.user.services.kannix = {
    description = "Kannix dev server";
    wantedBy = [ "default.target" ];
    after = [ "network.target" ];
    path = [
      pkgs.tmux
      pkgs.git
      pythonEnv
    ];
    serviceConfig = {
      Type = "simple";
      ExecStart = toString kannixDevScript;
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = srcDir;
    };
  };

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
