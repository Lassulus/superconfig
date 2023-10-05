{ config, lib, pkgs, ... }:

{
  krebs.secret.files.mysql_rootPassword = {
    path = "${config.services.mysql.dataDir}/mysql_rootPassword";
    owner.name = "mysql";
    source-path = "${config.krebs.secret.directory}/mysql_rootPassword";
  };

  services.mysql = {
    enable = true;
    dataDir = "/var/mysql";
    package = pkgs.mariadb;
  };

  systemd.services.mysql = {
    after = [
      config.krebs.secret.files.mysql_rootPassword.service
    ];
    partOf = [
      config.krebs.secret.files.mysql_rootPassword.service
    ];
  };

  lass.mysqlBackup = {
    enable = true;
    config.all = {};
  };
}

