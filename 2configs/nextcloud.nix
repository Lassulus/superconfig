{ config, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    hostName = "c.lassul.us";
    package = pkgs.nextcloud30;
    database.createLocally = true;
    config.dbtype = "pgsql";
    config.adminpassFile = "/var/lib/nextcloud/admin.pass";
    https = true;
  };

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
  };

  systemd.services.nextcloud-setup.serviceConfig.ExecStartPre = [
    "+${pkgs.writers.writeDash "install_admin_pw" ''
      mkdir -p /var/lib/nextcloud
      chown nextcloud:nextcloud /var/lib/nextcloud
      install -o nextcloud -g nextcloud -Dm0600 \
        ${config.clan.core.vars.generators.nextcloud.files."nextcloud_adminpass".path} \
        /var/lib/nextcloud/admin.pass
    ''}"
  ];

  clan.core.vars.generators.nextcloud = {
    files."nextcloud_adminpass" = { };
    migrateFact = "nextcloud";
    prompts.password = {
      description = "please enter the admin password for nextcloud";
      type = "hidden";
    };
    runtimeInputs = with pkgs; [ coreutils ];
    script = ''
      echo "$prompts/password" > "$out"/nextcloud_adminpass
    '';
  };
}
