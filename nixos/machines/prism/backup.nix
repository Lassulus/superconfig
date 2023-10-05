{ config, lib, pkgs, ... }:
{
  services.postgresqlBackup.enable = true;

  systemd.services.borgbackup-job-hetzner.serviceConfig.ReadWritePaths = [ "/var/log/telegraf" ];

  services.borgbackup.jobs.hetzner = {
    paths = [
      "/var/backup"
    ];
    exclude = [
      "*.pyc"
    ];
    repo = "u364341@u364341.your-storagebox.de:/./hetzner";
    encryption.mode = "none";
    compression = "auto,zstd";
    startAt = "*-*-* 01:00:00";
    # TODO: change backup key
    environment.BORG_RSH = "ssh -oPort=23 -i ${"${config.krebs.secret.directory}/borgbackup.ssh.id25519"}";
    preHook = ''
      set -x
    '';

    postHook = ''
      cat > /var/log/telegraf/borgbackup-job-hetzner.service <<EOF
      task,frequency=daily last_run=$(date +%s)i,state="$([[ $exitStatus == 0 ]] && echo ok || echo fail)"
      EOF
    '';

    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 4;
      monthly = 0;
    };
  };
}
