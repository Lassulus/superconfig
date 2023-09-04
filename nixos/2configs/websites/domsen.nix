{ config, pkgs, lib, ... }:

let

  inherit (import <stockholm/lib>)
    genid
    genid_uint31
  ;
  inherit (import <stockholm/lass/2configs/websites/util.nix> {inherit lib pkgs;})
    servePage
    serveOwncloud
    serveWordpress;

  msmtprc = pkgs.writeText "msmtprc" ''
    account localhost
      host localhost
    account default: localhost
  '';

  sendmail = pkgs.writeDash "msmtp" ''
    exec ${pkgs.msmtp}/bin/msmtp --read-envelope-from -C ${msmtprc} "$@"
  '';

in {
  imports = [
    ./default.nix
    ./sqlBackup.nix
    (servePage [ "aldonasiech.com" "www.aldonasiech.com" ])
    (servePage [ "apanowicz.de" "www.apanowicz.de" ])
    (servePage [ "reich-gebaeudereinigung.de" "www.reich-gebaeudereinigung.de" ])
    (servePage [ "illustra.de" "www.illustra.de" ])
    (servePage [ "event-extra.de" "www.event-extra.de" ])
    # (servePage [ "nirwanabluete.de" "www.nirwanabluete.de" ])
    (servePage [ "familienrat-hamburg.de" "www.familienrat-hamburg.de" ])
    (servePage [ "karlaskop.de" ])
    (servePage [
      "freemonkey.art"
      "www.freemonkey.art"
    ])
    (serveOwncloud [ "o.ubikmedia.de" ])
    (serveWordpress [
      "ubikmedia.de"
      "ubikmedia.eu"
      "youthtube.xyz"
      "joemisch.com"
      "weirdwednesday.de"
      "jarugadesign.de"
      "beesmooth.ch"

      "www.ubikmedia.eu"
      "www.youthtube.xyz"
      "www.ubikmedia.de"
      "www.joemisch.com"
      "www.weirdwednesday.de"
      "www.jarugadesign.de"
      "www.beesmooth.ch"

      "aldona2.ubikmedia.de"
      "cinevita.ubikmedia.de"
      "factscloud.ubikmedia.de"
      "illucloud.ubikmedia.de"
      "joemisch.ubikmedia.de"
      "nb.ubikmedia.de"
      "youthtube.ubikmedia.de"
      "weirdwednesday.ubikmedia.de"
      "freemonkey.ubikmedia.de"
      "jarugadesign.ubikmedia.de"
      "crypto4art.ubikmedia.de"
      "jarugadesign.ubikmedia.de"
      "beesmooth.ubikmedia.de"
    ])
  ];

  # https://github.com/nextcloud/server/issues/25436
  services.mysql.settings.mysqld.innodb_read_only_compressed = 0;

  services.mysql.ensureDatabases = [ "ubikmedia_de" "o_ubikmedia_de" ];
  services.mysql.ensureUsers = [
    { ensurePermissions = { "ubikmedia_de.*" = "ALL"; }; name = "nginx"; }
    { ensurePermissions = { "o_ubikmedia_de.*" = "ALL"; }; name = "nginx"; }
  ];

  services.nginx.virtualHosts."ubikmedia.de".locations."/piwika".extraConfig = ''
    try_files $uri $uri/ /index.php?$args;
  '';

  lass.mysqlBackup.config.all.databases = [
    "ubikmedia_de"
    "o_ubikmedia_de"
  ];

  services.phpfpm.phpOptions = ''
    sendmail_path = ${sendmail} -t
    upload_max_filesize = 100M
    post_max_size = 100M
    file_uploads = on
  '';

  systemd.services.nextcloud-setup.after = [ "secret-nextcloud_pw.service" ];
  krebs.secret.files.nextcloud_pw = {
    path = "/run/nextcloud.pw";
    owner.name = "nextcloud";
    group-name = "nextcloud";
    source-path = toString <secrets> + "/nextcloud_pw";
  };
  services.nextcloud = {
    enable = true;
    enableBrokenCiphersForSSE = false;
    hostName = "o.xanf.org";
    package = pkgs.nextcloud25;
    config = {
      adminpassFile = "/run/nextcloud.pw";
      overwriteProtocol = "https";
    };
    https = true;
  };
  services.nginx.virtualHosts."o.xanf.org" = {
    enableACME = true;
    forceSSL = true;
  };

  # MAIL STUFF
  # TODO: make into its own module

  services.roundcube = {
    enable = true;
    hostName = "mail.lassul.us";
    extraConfig = ''
      $config['smtp_debug'] = true;
      $config['smtp_host'] = "localhost:25";
    '';
  };
  services.dovecot2 = {
    enable = true;
    showPAMFailure = true;
    mailLocation = "maildir:~/Mail";
    sslServerCert = "/var/lib/acme/lassul.us/fullchain.pem";
    sslServerKey = "/var/lib/acme/lassul.us/key.pem";
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport pop3s"; target = "ACCEPT"; }
    { predicate = "-p tcp --dport imaps"; target = "ACCEPT"; }
  ];

  environment.systemPackages = [
    (pkgs.writers.writeDashBin "debug_exim" ''
      set -ef
      export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
      echo "$@" >> /tmp/xxx
      /run/wrappers/bin/shadow_verify_arg "${config.lass.usershadow.pattern}" "$2" "$3" 2>>/tmp/xxx1
      echo "ok" >> /tmp/yyy
      exit 23
    '')
  ];

  krebs.exim-smarthost = {
    authenticators.PLAIN = ''
      driver = plaintext
      public_name = PLAIN
      server_condition = ''${run{/run/wrappers/bin/shadow_verify_arg ${config.lass.usershadow.pattern} $auth2 $auth3}{yes}{no}}
    '';
    authenticators.LOGIN = ''
      driver = plaintext
      public_name = LOGIN
      server_prompts = "Username:: : Password::"
      server_condition = ''${run{/run/wrappers/bin/shadow_verify_arg ${config.lass.usershadow.pattern} $auth1 $auth2}{yes}{no}}
      # server_condition = ''${run{/run/current-system/sw/bin/debug_exim ${config.lass.usershadow.pattern} $auth1 $auth2}{yes}{no}}
    '';
    internet-aliases = [
      { from = "dma@ubikmedia.de"; to = "domsen"; }
      { from = "dma@ubikmedia.eu"; to = "domsen"; }
      { from = "mail@habsys.de"; to = "domsen"; }
      { from = "mail@habsys.eu"; to = "domsen"; }
      { from = "hallo@apanowicz.de"; to = "domsen"; }
      { from = "bruno@apanowicz.de"; to = "bruno"; }
      { from = "mail@jla-trading.com"; to = "jla-trading"; }
      { from = "jms@ubikmedia.eu"; to = "jms"; }
      { from = "ms@ubikmedia.eu"; to = "ms"; }
      { from = "ubik@ubikmedia.eu"; to = "domsen, jms, ms"; }
      { from = "kontakt@alewis.de"; to ="klabusterbeere"; }
      { from = "hallo@jarugadesign.de"; to ="kasia"; }
      { from = "noreply@beeshmooth.ch"; to ="besmooth@gmx.ch"; }

      { from = "testuser@lassul.us"; to = "testuser"; }
      { from = "testuser@ubikmedia.eu"; to = "testuser"; }
    ];
    sender_domains = [
      "jla-trading.com"
      "ubikmedia.eu"
      "ubikmedia.de"
      "apanowicz.de"
      "alewis.de"
      "jarugadesign.de"
      "beesmooth.ch"
      "event-extra.de"
    ];
    dkim = [
      { domain = "ubikmedia.eu"; }
      { domain = "apanowicz.de"; }
      { domain = "beesmooth.ch"; }
    ];
  };
  services.borgbackup.jobs.hetzner.paths = [
    "/home/xanf"
    "/home/domsen"
    "/home/bruno"
    "/home/jla-trading"
    "/home/jms"
    "/home/ms"
    "/home/bui"
    "/home/klabusterbeere"
    "/home/akayguen"
    "/home/kasia"
    "/home/dif"
    "/home/lavafilms"
    "/home/movematchers"
    "/home/blackphoton"
    "/home/avada"
    "/home/sts"
    "/home/familienrat"
  ];
  users.users.UBIK-SFTP = {
    uid = genid_uint31 "UBIK-SFTP";
    home = "/home/UBIK-SFTP";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.xanf = {
    uid = genid_uint31 "xanf";
    group = "xanf";
    home = "/home/xanf";
    useDefaultShell = true;
    createHome = false; # creathome forces permissions
    isNormalUser = true;
  };

  users.users.domsen = {
    uid = genid_uint31 "domsen";
    description = "maintenance acc for domsen";
    home = "/home/domsen";
    useDefaultShell = true;
    extraGroups = [ "syncthing" "download" "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.bruno = {
    uid = genid_uint31 "bruno";
    home = "/home/bruno";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.jla-trading = {
    uid = genid_uint31 "jla-trading";
    home = "/home/jla-trading";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.jms = {
    uid = genid_uint31 "jms";
    home = "/home/jms";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.ms = {
    uid = genid_uint31 "ms";
    home = "/home/ms";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.testuser = {
    uid = genid_uint31 "testuser";
    home = "/home/testuser";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  #users.users.akayguen = {
  #  uid = genid_uint31 "akayguen";
  #  home = "/home/akayguen";
  #  useDefaultShell = true;
  #  createHome = true;
  #  isNormalUser = true;
  #};

  users.users.bui = {
    uid = genid_uint31 "bui";
    home = "/home/bui";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.klabusterbeere = {
    uid = genid_uint31 "klabusterbeere";
    home = "/home/klabusterbeere";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.kasia = {
    uid = genid_uint31 "kasia";
    home = "/home/kasia";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.XANF_TEAM = {
    uid = genid_uint31 "XANF_TEAM";
    group = "xanf";
    home = "/home/XANF_TEAM";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.dif = {
    uid = genid_uint31 "dif";
    home = "/home/dif";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.lavafilms = {
    uid = genid_uint31 "lavafilms";
    home = "/home/lavafilms";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.movematchers = {
    uid = genid_uint31 "movematchers";
    home = "/home/movematchers";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.blackphoton = {
    uid = genid_uint31 "blackphoton";
    home = "/home/blackphoton";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.line = {
    uid = genid_uint31 "line";
    home = "/home/line";
    useDefaultShell = true;
    # extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.avada = {
    uid = genid_uint31 "avada";
    home = "/home/avada";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.sts = {
    uid = genid_uint31 "sts";
    home = "/home/sts";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.familienrat = {
    uid = genid_uint31 "familienrat";
    home = "/home/familienrat";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };
  krebs.acl."/srv/http/familienrat-hamburg.de"."u:familienrat:rwX" = {};
  krebs.acl."/srv/http"."u:familienrat:X" = {
    default = false;
    recursive = false;
  };

  users.groups.xanf = {};

  krebs.on-failure.plans.restic-backups-domsen = {
    journalctl = {
      lines = 1000;
    };
  };

  services.restic.backups.domsen = {
    initialize = true;
    repository = "/backups/domsen";
    passwordFile = toString <secrets> + "/domsen_backup_pw";
    timerConfig = { OnCalendar = "00:05"; RandomizedDelaySec = "5h"; };
    paths = [
      "/home/domsen/Mail"
      "/home/ms/Mail"
      "/home/klabusterbeere/Mail"
      "/home/jms/Mail"
      "/home/kasia/Mail"
      "/home/bruno/Mail"
      "/home/akayguen/Mail"
      "/backups/sql_dumps"
    ];
  };

  services.syncthing.declarative.folders = {
    domsen-backups = {
      path = "/backups/domsen";
      devices = [ "domsen-backup" ];
    };
    domsen-backup-srv-http = {
      path = "/srv/http";
      devices = [ "domsen-backup" ];
    };
  };

  system.activationScripts.domsen-backups = ''
    ${pkgs.coreutils}/bin/chmod 750 /backups
  '';

  # takes too long!!
  # krebs.acl."/srv/http"."u:syncthing:rwX" = {};
  # krebs.acl."/srv/http"."u:nginx:rwX" = {};
  # krebs.acl."/srv/http/ubikmedia.de"."u:avada:rwX" = {};
  krebs.acl."/home/xanf/XANF_TEAM"."g:xanf:rwX" = {};
  krebs.acl."/home/xanf"."g:xanf:X" = {
    default = false;
    recursive = false;
  };
}

