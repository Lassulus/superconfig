{
  self,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/autoupdate.nix

    self.inputs.stockholm.nixosModules.exim-smarthost
  ];

  krebs.build.host = config.krebs.hosts.ubik;
  clan.password-store.targetDirectory = "/var/state/secrets";
  clan.core.vars.password-store.secretLocation = "/var/state/secret-vars";

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBFGMjH0+Dco6DVFZbByENMci8CFTLXCL7j53yctPnM";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # nextcloud
  services.nginx.virtualHosts."c.apanowicz.de" = {
    enableACME = true;
    forceSSL = true;
  };
  services.nextcloud = {
    enable = true;
    hostName = "c.apanowicz.de";
    package = pkgs.nextcloud31;
    config.dbtype = "sqlite";
    config.adminpassFile = config.clan.core.vars.generators.nextcloud-pw.files.nextcloud-pw.path;
    https = true;
    maxUploadSize = "9001M";
  };
  clan.core.vars.generators.nextcloud-pw = {
    prompts.nextcloud-pw.persist = true;
  };

  # mail
  lass.usershadow.enable = true;
  services.nginx.virtualHosts."mail.ubikmedia.eu" = {
    enableACME = true;
    forceSSL = true;
  };
  services.roundcube = {
    enable = true;
    hostName = "mail.ubikmedia.eu";
    extraConfig = ''
      $config['smtp_debug'] = true;
      $config['smtp_host'] = "localhost:25";
    '';
  };
  services.dovecot2 = {
    enable = true;
    showPAMFailure = true;
    mailLocation = "maildir:~/Mail";
    sslServerCert = "/var/lib/acme/mail.ubikmedia.eu/fullchain.pem";
    sslServerKey = "/var/lib/acme/mail.ubikmedia.eu/key.pem";
  };
  krebs.exim-smarthost = {
    ssl_cert = "/var/lib/acme/mail.ubikmedia.eu/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.ubikmedia.eu/key.pem";
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
    ];
    dkim = [
      { domain = "ubikmedia.eu"; }
      { domain = "apanowicz.de"; }
      { domain = "beesmooth.ch"; }
    ];
  };

  # users
  users.groups.xanf = { };
  users.users.UBIK-SFTP = {
    uid = pkgs.stockholm.lib.genid_uint31 "UBIK-SFTP";
    home = "/home/UBIK-SFTP";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.xanf = {
    uid = pkgs.stockholm.lib.genid_uint31 "xanf";
    group = "xanf";
    home = "/home/xanf";
    useDefaultShell = true;
    createHome = false; # creathome forces permissions
    isNormalUser = true;
  };

  users.users.domsen = {
    uid = pkgs.stockholm.lib.genid_uint31 "domsen";
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
    uid = pkgs.stockholm.lib.genid_uint31 "bruno";
    home = "/home/bruno";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.jla-trading = {
    uid = pkgs.stockholm.lib.genid_uint31 "jla-trading";
    home = "/home/jla-trading";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.jms = {
    uid = pkgs.stockholm.lib.genid_uint31 "jms";
    home = "/home/jms";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.ms = {
    uid = pkgs.stockholm.lib.genid_uint31 "ms";
    home = "/home/ms";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.testuser = {
    uid = pkgs.stockholm.lib.genid_uint31 "testuser";
    home = "/home/testuser";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.bui = {
    uid = pkgs.stockholm.lib.genid_uint31 "bui";
    home = "/home/bui";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.klabusterbeere = {
    uid = pkgs.stockholm.lib.genid_uint31 "klabusterbeere";
    home = "/home/klabusterbeere";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.kasia = {
    uid = pkgs.stockholm.lib.genid_uint31 "kasia";
    home = "/home/kasia";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.XANF_TEAM = {
    uid = pkgs.stockholm.lib.genid_uint31 "XANF_TEAM";
    group = "xanf";
    home = "/home/XANF_TEAM";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.dif = {
    uid = pkgs.stockholm.lib.genid_uint31 "dif";
    home = "/home/dif";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.lavafilms = {
    uid = pkgs.stockholm.lib.genid_uint31 "lavafilms";
    home = "/home/lavafilms";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.movematchers = {
    uid = pkgs.stockholm.lib.genid_uint31 "movematchers";
    home = "/home/movematchers";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.blackphoton = {
    uid = pkgs.stockholm.lib.genid_uint31 "blackphoton";
    home = "/home/blackphoton";
    useDefaultShell = true;
    extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.line = {
    uid = pkgs.stockholm.lib.genid_uint31 "line";
    home = "/home/line";
    useDefaultShell = true;
    # extraGroups = [ "xanf" ];
    createHome = true;
    isNormalUser = true;
  };

  users.users.avada = {
    uid = pkgs.stockholm.lib.genid_uint31 "avada";
    home = "/home/avada";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

  users.users.familienrat = {
    uid = pkgs.stockholm.lib.genid_uint31 "familienrat";
    home = "/home/familienrat";
    useDefaultShell = true;
    createHome = true;
    isNormalUser = true;
  };

}
