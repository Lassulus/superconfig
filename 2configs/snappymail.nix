{ config, pkgs, ... }:
let
  snappymail = pkgs.snappymail;
  dataDir = "/var/lib/snappymail";
  pool = "snappymail";
  fpmSocket = config.services.phpfpm.pools.${pool}.socket;
in
{
  services.phpfpm.pools.${pool} = {
    user = "snappymail";
    group = "snappymail";
    settings = {
      "listen.owner" = "nginx";
      "listen.group" = "nginx";
      "pm" = "dynamic";
      "pm.max_children" = 4;
      "pm.start_servers" = 1;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 2;
    };
    phpOptions = ''
      upload_max_filesize = 25M
      post_max_size = 25M
    '';
    phpEnv = {
      SNAPPYMAIL_DATA_PATH = dataDir;
    };
  };

  users.users.snappymail = {
    isSystemUser = true;
    group = "snappymail";
    home = dataDir;
    createHome = true;
  };
  users.groups.snappymail = { };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 snappymail snappymail -"
  ];

  services.nginx.virtualHosts."mail.lassul.us" = {
    forceSSL = true;
    useACMEHost = "mail.lassul.us";
    root = "${snappymail}";
    locations."/" = {
      index = "index.php";
      tryFiles = "$uri $uri/ /index.php$is_args$args";
    };
    locations."~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${fpmSocket};
        include ${pkgs.nginx}/conf/fastcgi.conf;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param SNAPPYMAIL_DATA_PATH ${dataDir};
      '';
    };
    locations."~ /\\." = {
      extraConfig = "deny all;";
    };
    locations."^~ /data" = {
      extraConfig = "deny all;";
    };
  };
}
