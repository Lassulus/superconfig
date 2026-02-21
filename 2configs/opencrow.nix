{
  self,
  config,
  pkgs,
  ...
}:
let
  opencrow = self.inputs.opencrow.packages.${pkgs.system}.opencrow;
  pi = self.inputs.llm-agents.packages.${pkgs.system}.pi;
in
{
  users.users.bot = {
    isNormalUser = true;
    home = "/home/bot";
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
    packages = [
      opencrow
      pi
      pkgs.curl
      pkgs.jq
      pkgs.lynx
    ];
  };

  clan.core.vars.generators.opencrow = {
    prompts.matrix-access-token = {
      description = "Matrix access token for @opencrow:lassul.us - register via synapse admin API using the registration_shared_secret";
      type = "hidden";
    };
    files."opencrow.env" = { };
    script = ''
      cat > "$out/opencrow.env" << EOF
      OPENCROW_MATRIX_ACCESS_TOKEN=$(cat $prompts/matrix-access-token)
      EOF
    '';
  };

  systemd.services.opencrow = {
    description = "OpenCrow Matrix Bot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [
      opencrow
      pi
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.lynx
    ];

    environment = {
      OPENCROW_MATRIX_HOMESERVER = "https://matrix.lassul.us";
      OPENCROW_ALLOWED_USERS = "@lassulus:lassul.us";
      OPENCROW_MATRIX_USER_ID = "@opencrow:lassul.us";
      OPENCROW_MATRIX_DEVICE_ID = "AYBPKDHIDV";
      OPENCROW_PI_SESSION_DIR = "/home/bot/opencrow/sessions";
      OPENCROW_PI_WORKING_DIR = "/home/bot/opencrow";
      OPENCROW_PI_SKILLS = "${opencrow}/share/opencrow/skills/web";
      OPENCROW_PI_SKILLS_DIR = "/home/bot/skills";
      OPENCROW_HEARTBEAT_INTERVAL = "10m";
      OPENCROW_SOUL_FILE = "${opencrow}/share/opencrow/SOUL.md";
      PI_CODING_AGENT_DIR = "/home/bot/opencrow/pi-agent";
    };

    serviceConfig = {
      EnvironmentFile = config.clan.core.vars.generators.opencrow.files."opencrow.env".path;
      ExecStart = "${opencrow}/bin/opencrow";
      Restart = "on-failure";
      RestartSec = 10;
      User = "bot";
      Group = "users";
      WorkingDirectory = "/home/bot/opencrow";
    };
  };

  # ensure working directory exists
  systemd.tmpfiles.rules = [
    "d /home/bot/opencrow 0750 bot users -"
    "d /home/bot/opencrow/sessions 0750 bot users -"
    "d /home/bot/opencrow/pi-agent 0750 bot users -"
  ];
}
