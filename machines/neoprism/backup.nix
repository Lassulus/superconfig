{ config, pkgs, ... }:
{
  systemd.services.borgbackup-job-hetzner.serviceConfig.ReadWritePaths = [
    "/var/log/telegraf"
  ];

  clan.core.vars.generators.borgbackup = {
    files."borgbackup.ssh.id25519" = { };
    files."borgbackup.ssh.id25519.pub".secret = false;
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f $out/borgbackup.ssh.id25519
    '';
  };

  # Ensure backup directory exists for pg_dump
  systemd.tmpfiles.rules = [
    "d /var/backup 0700 root root -"
    "d /var/backup/postgresql 0700 root root -"
  ];

  services.borgbackup.jobs.hetzner = {
    paths = [
      "/var/backup"
      "/var/lib/bitwarden_rs"
      "/var/lib/matrix-synapse/media_store/local_content"
      "/var/lib/radicale"
      "/home/bot"
    ];
    exclude = [
      "*.pyc"
      "/home/bot/.cache"
      "/home/bot/.nix-defexpr"
      "/home/bot/.nix-profile"
    ];
    repo = "u550643@u550643.your-storagebox.de:/./neoprism";
    encryption.mode = "none";
    compression = "auto,zstd";
    startAt = "*-*-* 03:00:00";
    environment.BORG_RSH =
      let
        knownHostsFile = pkgs.writeText "storagebox-known-hosts" ''
          [u550643.your-storagebox.de]:23 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs
        '';
      in
      "ssh -oPort=23 -oUserKnownHostsFile=${knownHostsFile} -i ${
        config.clan.core.vars.generators.borgbackup.files."borgbackup.ssh.id25519".path
      }";

    readWritePaths = [
      "/var/backup"
      "/var/lib/hedgedoc"
    ];

    preHook = ''
      set -x
      # Dump matrix-synapse PostgreSQL database (14GB, compresses well)
      ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/pg_dump \
        matrix-synapse | ${pkgs.gzip}/bin/gzip > /var/backup/postgresql/matrix-synapse.sql.gz

      # Dump hedgedoc SQLite database (172MB) safely
      ${pkgs.sqlite}/bin/sqlite3 /var/lib/hedgedoc/db.sqlite ".backup /var/backup/hedgedoc.sqlite"
    '';

    postHook = ''
      cat > /var/log/telegraf/borgbackup-job-hetzner.service <<EOF
      task,frequency=daily last_run=$(date +%s)i,state="$([[ $exitStatus == 0 ]] && echo ok || echo fail)"
      EOF
    '';

    prune.keep = {
      within = "1d";
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
  };
}
