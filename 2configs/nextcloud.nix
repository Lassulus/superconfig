{ config, pkgs, ... }:
{
  services.nextcloud = {
    enable = true;
    hostName = "c.lassul.us";
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
        ${config.clanCore.facts.services.nextcloud.secret.nextcloud_adminpass.path} \
        /var/lib/nextcloud/admin.pass
    ''}"
  ];

  clanCore.facts.services."nextcloud" = {
    secret."nextcloud_adminpass" = { };
    generator.path = with pkgs; [ coreutils ];
    generator.prompt = ''
      please enter the admin password for nextcloud_adminpass:
    '';
    generator.script = ''
      echo "$prompt_value" > "$secrets"/adminpass
    '';
  };
}
