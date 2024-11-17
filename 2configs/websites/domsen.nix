{
  self,
  config,
  pkgs,
  lib,
  ...
}:

let

  inherit (self.inputs.stockholm.lib)
    genid_uint31
    ;
  inherit (import ./util.nix { inherit lib pkgs; })
    servePage
    serveWordpress
    ;

  msmtprc = pkgs.writeText "msmtprc" ''
    account localhost
      host localhost
    account default: localhost
  '';

  sendmail = pkgs.writeDash "msmtp" ''
    exec ${pkgs.msmtp}/bin/msmtp --read-envelope-from -C ${msmtprc} "$@"
  '';

in
{
  imports = [
    self.inputs.stockholm.nixosModules.acl
    self.inputs.stockholm.nixosModules.on-failure
    ./default.nix
    ./sqlBackup.nix
    (servePage [
      "aldonasiech.com"
      "www.aldonasiech.com"
    ])
    (servePage [
      "apanowicz.de"
      "www.apanowicz.de"
    ])
    (servePage [
      "reich-gebaeudereinigung.de"
      "www.reich-gebaeudereinigung.de"
    ])
    (servePage [
      "illustra.de"
      "www.illustra.de"
    ])
    # (servePage [ "nirwanabluete.de" "www.nirwanabluete.de" ])
    (servePage [
      "familienrat-hamburg.de"
      "www.familienrat-hamburg.de"
    ])
    (servePage [ "karlaskop.de" ])
    (servePage [
      "freemonkey.art"
      "www.freemonkey.art"
    ])
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

  services.mysql.ensureDatabases = [
    "ubikmedia_de"
    "o_ubikmedia_de"
  ];
  services.mysql.ensureUsers = [
    {
      ensurePermissions = {
        "ubikmedia_de.*" = "ALL";
      };
      name = "nginx";
    }
    {
      ensurePermissions = {
        "o_ubikmedia_de.*" = "ALL";
      };
      name = "nginx";
    }
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

  clanCore.facts.services.nextcloud = {
    secret."nextcloud_pw" = { };
    generator.script = ''
      cat > "$secrets"/nexcloud_pw;
    '';
    generator.prompt = ''
      enter initial admin password for nextcloud
    '';
  };
  systemd.services.nextcloud-setup.after = [ "secret-nextcloud_pw.service" ];
  krebs.secret.files.nextcloud_pw = {
    path = "/run/nextcloud.pw";
    owner.name = "nextcloud";
    group-name = "nextcloud";
    source-path = "${config.krebs.secret.directory}/nextcloud_pw";
  };
  services.nextcloud = {
    enable = true;
    hostName = "o.xanf.org";
    package = pkgs.nextcloud28;
    settings.overwriteProtocol = "https";
    config.adminpassFile = "/run/nextcloud.pw";
    https = true;
  };
  services.nginx.virtualHosts."o.xanf.org" = {
    enableACME = true;
    forceSSL = true;
  };
  services.nginx.virtualHosts."weirdweekender.de" = {
    serverAliases = [ "www.weirdweekender.de" ];
    enableACME = true;
    forceSSL = true;
    locations."/".extraConfig = ''
      return 301 https://weirdwednesday.de/weirdweekender/;
    '';
  };
  services.nginx.virtualHosts."shop.weirdwednesday.de" = {
    enableACME = true;
    addSSL = true;
    locations."/".extraConfig = ''
      return 301 https://weirdwednesday0711.etsy.com;
    '';
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
    {
      predicate = "-p tcp --dport pop3s";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport imaps";
      target = "ACCEPT";
    }
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
      {
        from = "dma@ubikmedia.de";
        to = "domsen";
      }
      {
        from = "dma@ubikmedia.eu";
        to = "domsen";
      }
      {
        from = "mail@habsys.de";
        to = "domsen";
      }
      {
        from = "mail@habsys.eu";
        to = "domsen";
      }
      {
        from = "hallo@apanowicz.de";
        to = "domsen";
      }
      {
        from = "bruno@apanowicz.de";
        to = "bruno";
      }
      {
        from = "mail@jla-trading.com";
        to = "jla-trading";
      }
      {
        from = "jms@ubikmedia.eu";
        to = "jms";
      }
      {
        from = "ms@ubikmedia.eu";
        to = "ms";
      }
      {
        from = "ubik@ubikmedia.eu";
        to = "domsen, jms, ms";
      }
      {
        from = "kontakt@alewis.de";
        to = "klabusterbeere";
      }
      {
        from = "hallo@jarugadesign.de";
        to = "kasia";
      }
      {
        from = "noreply@beeshmooth.ch";
        to = "besmooth@gmx.ch";
      }

      {
        from = "testuser@lassul.us";
        to = "testuser";
      }
      {
        from = "testuser@ubikmedia.eu";
        to = "testuser";
      }
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
  clanCore.facts.services."ubikmedia.eu-dkim" = {
    secret."ubikmedia.eu.dkim.priv" = { };
    public."ubikmedia.eu.dkim.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssl
    ];
    generator.script = ''
      openssl genrsa -out "$secrets"/ubikmedia.eu.dkim.priv 1024
      openssl rsa -in "$secrets"/ubikmedia.eu.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$facts"/ubikmedia.eu.dkim.pub
    '';
  };
  clanCore.facts.services."apanowicz.de-dkim" = {
    secret."apanowicz.de.dkim.priv" = { };
    public."apanowicz.de.dkim.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssl
    ];
    generator.script = ''
      openssl genrsa -out "$secrets"/apanowicz.de.dkim.priv 1024
      openssl rsa -in "$secrets"/apanowicz.de.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$facts"/apanowicz.de.dkim.pub
    '';
  };
  clanCore.facts.services."beesmooth.ch-dkim" = {
    secret."beesmooth.ch.dkim.priv" = { };
    public."beesmooth.ch.dkim.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssl
    ];
    generator.script = ''
      openssl genrsa -out "$secrets"/beesmooth.ch.dkim.priv 1024
      openssl rsa -in "$secrets"/beesmooth.ch.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$facts"/beesmooth.ch.dkim.pub
    '';
  };
  clanCore.facts.services."freemonkey.art" = {
    secret."beesmooth.ch.dkim.priv" = { };
    public."beesmooth.ch.dkim.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssl
    ];
    generator.script = ''
      openssl genrsa -out "$secrets"/beesmooth.ch.dkim.priv 1024
      openssl rsa -in "$secrets"/beesmooth.ch.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$facts"/beesmooth.ch.dkim.pub
    '';
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
  users.users.domsen = {
    uid = genid_uint31 "domsen";
    description = "maintenance acc for domsen";
    home = "/home/domsen";
    useDefaultShell = true;
    extraGroups = [
      "syncthing"
      "download"
      "xanf"
    ];
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

  users.users.klabusterbeere = {
    uid = genid_uint31 "klabusterbeere";
    home = "/home/klabusterbeere";
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

  users.users.pr = {
    uid = genid_uint31 "pr";
    home = "/home/pr";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  krebs.acl."/srv/http/familienrat-hamburg.de"."u:familienrat:rwX" = { };
  krebs.acl."/srv/http"."u:familienrat:X" = {
    default = false;
    recursive = false;
  };

  krebs.on-failure.plans.restic-backups-domsen = {
    journalctl = {
      lines = 1000;
    };
  };

  services.restic.backups.domsen = {
    initialize = true;
    repository = "/backups/domsen";
    passwordFile = "${config.krebs.secret.directory}/domsen_backup_pw";
    timerConfig = {
      OnCalendar = "00:05";
      RandomizedDelaySec = "5h";
    };
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

  # services.syncthing.settings.folders = {
  #   domsen-backups = {
  #     path = "/backups/domsen";
  #     devices = [ "domsen-backup" ];
  #   };
  #   domsen-backup-srv-http = {
  #     path = "/srv/http";
  #     devices = [ "domsen-backup" ];
  #   };
  # };

  system.activationScripts.domsen-backups = ''
    ${pkgs.coreutils}/bin/chmod 750 /backups
  '';

  # takes too long!!
  # krebs.acl."/srv/http"."u:syncthing:rwX" = {};
  # krebs.acl."/srv/http"."u:nginx:rwX" = {};
  # krebs.acl."/srv/http/ubikmedia.de"."u:avada:rwX" = {};
}
