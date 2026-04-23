{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  relayHosts = map (host: host.nets.retiolum.ip6.addr) [
    config.krebs.hosts.aergia
    config.krebs.hosts.ignavia
    config.krebs.hosts.coaxmetal
    config.krebs.hosts.green
    config.krebs.hosts.mors
  ];

  mynetworks = map (ip: "[${ip}]") relayHosts;
in
{
  imports = [
    self.inputs.nixos-mailserver.nixosModules.default
  ];

  mailserver = {
    enable = true;
    fqdn = "mail.lassul.us";
    domains = [ "lassul.us" ];

    loginAccounts = {
      "lass@lassul.us" = {
        hashedPasswordFile =
          config.clan.core.vars.generators.mailserver-lass.files."lass-mail-password-hash".path;
        aliases = [
          "postmaster@lassul.us"
          "root@lassul.us"
          "abuse@lassul.us"
          "hostmaster@lassul.us"
          "webmaster@lassul.us"
          "security@lassul.us"
          "noc@lassul.us"
          "mailer-daemon@lassul.us"
          "nobody@lassul.us"
          "lassulus@lassul.us"
        ];
        catchAll = [ "lassul.us" ];
      };
      "bot@lassul.us" = {
        hashedPasswordFile =
          config.clan.core.vars.generators.mailserver-bot.files."bot-mail-password-hash".path;
      };
    };

    # TLS via existing ACME cert
    x509.useACMEHost = "mail.lassul.us";

    # DKIM — auto-managed by module
    dkimSigning = true;
    dkimSelector = "mail";

    # ManageSieve: lets mail clients manage sieve rules dynamically (port 4190)
    enableManageSieve = true;

    # Full-text search for IMAP clients
    fullTextSearch = {
      enable = true;
      memoryLimit = 500;
    };

    stateVersion = 3;

    # virtual.All mailbox needs more memory to sync all folders
    imapMemoryLimit = 1024;
  };

  # nixos-mailserver mkForces virtualMail without homeMode; match its priority
  users.users.virtualMail = lib.mkOverride 50 { homeMode = "2770"; };

  # POSIX ACL default ensures new files inherit lass access (needed for muchsync hardlinks)
  systemd.services.dovecot.serviceConfig.ExecStartPost = [
    "+${pkgs.acl}/bin/setfacl -R -m u:lass:rwX /var/vmail/lassul.us/lass/mail"
    "+${pkgs.acl}/bin/setfacl -R -d -m u:lass:rwX /var/vmail/lassul.us/lass/mail"
  ];

  # Password generation for mail accounts
  clan.core.vars.generators.mailserver-lass = {
    files."lass-mail-password" = { };
    files."lass-mail-password-hash" = { };
    runtimeInputs = with pkgs; [
      coreutils
      mkpasswd
      pwgen
    ];
    script = ''
      pwgen -s 32 1 > "$out/lass-mail-password"
      mkpasswd -sm bcrypt < "$out/lass-mail-password" > "$out/lass-mail-password-hash"
    '';
  };

  clan.core.vars.generators.mailserver-bot = {
    files."bot-mail-password" = { };
    files."bot-mail-password-hash" = { };
    files."mail.env" = { };
    runtimeInputs = with pkgs; [
      coreutils
      mkpasswd
      pwgen
    ];
    script = ''
      pwgen -s 32 1 > "$out/bot-mail-password"
      mkpasswd -sm bcrypt < "$out/bot-mail-password" > "$out/bot-mail-password-hash"
      cat > "$out/mail.env" << EOF
      IMAP_USER=bot@lassul.us
      IMAP_PASSWORD=$(cat "$out/bot-mail-password")
      IMAP_HOST=localhost
      EOF
    '';
  };

  # Retiolum relay: allow krebs hosts to relay through postfix
  services.postfix.settings.main.mynetworks = lib.mkForce (
    [
      "127.0.0.0/8"
      "[::1]/128"
    ]
    ++ mynetworks
  );

  # ACME cert — reuse existing setup
  security.acme.certs."mail.lassul.us" = {
    group = "lasscert";
    webroot = "/var/lib/acme/acme-challenge";
  };
  users.groups.lasscert.members = [
    "dovecot2"
    "postfix"
    "nginx"
  ];

  # Firewall: SMTP(25), submission(587), submissions(465), IMAPS(993), ManageSieve(4190)
  networking.firewall.allowedTCPPorts = [
    25
    587
    465
    993
    4190
  ];

  # muchsync: lass user needs access to vmail for notmuch/muchsync
  users.groups.virtualMail.members = [ "lass" ];
  systemd.tmpfiles.rules = [
    "L+ /home/lass/Maildir - - - - /var/vmail/lassul.us/lass/mail"
    "z /var/vmail/lassul.us 2770 virtualMail virtualMail -"
    "z /var/vmail/lassul.us/lass 2770 virtualMail virtualMail -"
    "d /var/vmail/lassul.us/lass/mail 2770 virtualMail virtualMail -"
  ];

  # Thunderbird autoconfig
  services.nginx.virtualHosts."autoconfig.lassul.us" = {
    forceSSL = true;
    enableACME = true;
    locations."= /mail/config-v1.1.xml".extraConfig = ''
      default_type application/xml;
      return 200 '<?xml version="1.0" encoding="UTF-8"?>
        <clientConfig version="1.1">
          <emailProvider id="lassul.us">
            <domain>lassul.us</domain>
            <displayName>lassul.us Mail</displayName>
            <displayShortName>lassul.us</displayShortName>
            <incomingServer type="imap">
              <hostname>mail.lassul.us</hostname>
              <port>993</port>
              <socketType>SSL</socketType>
              <authentication>password-cleartext</authentication>
              <username>%EMAILADDRESS%</username>
            </incomingServer>
            <outgoingServer type="smtp">
              <hostname>mail.lassul.us</hostname>
              <port>465</port>
              <socketType>SSL</socketType>
              <authentication>password-cleartext</authentication>
              <username>%EMAILADDRESS%</username>
            </outgoingServer>
          </emailProvider>
        </clientConfig>';
    '';
  };

  # Provision virtual mailbox config to a writable directory (nix store is read-only,
  # and the ACL plugin needs to write dovecot-acl-list next to the virtual config)
  systemd.tmpfiles.settings."dovecot-virtual" = {
    "/var/vmail/virtual-config".d = {
      user = "virtualMail";
      group = "virtualMail";
      mode = "0750";
    };
    "/var/vmail/virtual-config/Unread".d = {
      user = "virtualMail";
      group = "virtualMail";
      mode = "0750";
    };
    "/var/vmail/virtual-config/Unread/dovecot-virtual".f = {
      user = "virtualMail";
      group = "virtualMail";
      mode = "0640";
      argument = "*\n-notmuch\n-fts-flatcurve\n  unseen\n";
    };
    "/var/vmail/virtual-config/All".d = {
      user = "virtualMail";
      group = "virtualMail";
      mode = "0750";
    };
    "/var/vmail/virtual-config/All/dovecot-virtual".f = {
      user = "virtualMail";
      group = "virtualMail";
      mode = "0640";
      argument = "*\n-notmuch\n-fts-flatcurve\n  all\n";
    };
  };

  # Dovecot virtual mailbox + ACL-restricted shared namespace for bot
  services.dovecot2.settings = {
    mail_plugins = {
      virtual = true;
      acl = true;
    };

    # ACL plugin settings (top-level since dovecot 2.4)
    acl = "vfile";
    acl_shared_dict = "file:/var/vmail/shared-mailboxes.db";

    "namespace shared" = {
      type = "shared";
      separator = ".";
      prefix = "shared.%{user | username}.";
      location = "maildir:/var/vmail/lassul.us/%{user | username}/mail:LAYOUT=Maildir++";
      subscriptions = false;
      list = "children";
    };

    "namespace virtual" = {
      prefix = "virtual.";
      separator = ".";
      location = "virtual:/var/vmail/virtual-config:INDEX=/var/vmail/virtual-indexes/%{user}";
      subscriptions = false;
      "mailbox Unread".auto = "subscribe";
      "mailbox All".auto = "subscribe";
    };
  };

  # Write dovecot-acl files to grant bot read-only + flag access to lass's mail
  systemd.services.dovecot-acl-sync = {
    description = "Sync dovecot ACL files for bot shared access";
    after = [ "dovecot.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "virtualMail";
      Group = "virtualMail";
    };
    # l=lookup, r=read, w=write-flags, s=write-seen (no insert/delete/expunge)
    script = ''
      acl_line="user=bot@lassul.us lrws"
      # Only write ACL in mailbox root dirs, skip cur/new/tmp/notmuch subdirs
      find /var/vmail/lassul.us/lass/mail -type d \
        -not -name cur -not -name new -not -name tmp \
        -not -path '*/.notmuch/*' -not -name .notmuch \
        -not -path '*/fts-flatcurve/*' -not -name fts-flatcurve \
        | while IFS= read -r dir; do
        acl_file="$dir/dovecot-acl"
        if [ ! -f "$acl_file" ] || [ "$(cat "$acl_file")" != "$acl_line" ]; then
          echo "$acl_line" > "$acl_file"
        fi
      done
    '';
  };
  systemd.timers.dovecot-acl-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1h";
    };
  };

  # notmuch + muchsync + msmtp for CLI mail access
  environment.systemPackages = [
    self.packages.${pkgs.system}.notmuch
    pkgs.muchsync
    pkgs.msmtp
  ];

  # After muchsync writes tags to notmuch DB, the Maildir filenames don't get updated
  # (muchsync bypasses notmuch's flag sync). This watches the xapian DB for changes and
  # renames files to add/remove the S (Seen) flag based on the notmuch unread tag.
  systemd.paths.notmuch-flag-sync = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/var/vmail/lassul.us/lass/mail/.notmuch/xapian";
  };
  systemd.services.notmuch-flag-sync = {
    description = "Sync notmuch tags to Maildir flags after muchsync";
    serviceConfig = {
      Type = "oneshot";
      User = "lass";
      Group = "virtualMail";
      ExecStart = pkgs.writeShellScript "notmuch-flag-sync" ''
        export NOTMUCH_CONFIG="${
          self.packages.${pkgs.system}.notmuch.passthru.configuration.configFile.path
        }"
        # First, pick up any IMAP flag changes into notmuch
        ${pkgs.notmuch}/bin/notmuch new --quiet 2>/dev/null || true
        # Add S flag to files notmuch considers read but that lack it
        ${pkgs.notmuch}/bin/notmuch search --output=files 'NOT tag:unread' \
          | ${pkgs.gnugrep}/bin/grep '/cur/' \
          | while IFS= read -r f; do
              [ -f "$f" ] || continue
              flags="''${f##*:2,}"
              case "$flags" in *S*) continue ;; esac
              base="''${f%:2,*}"
              mv "$f" "''${base}:2,''${flags}S"
            done
        # Remove S flag from files notmuch considers unread but that have it
        ${pkgs.notmuch}/bin/notmuch search --output=files 'tag:unread' \
          | ${pkgs.gnugrep}/bin/grep '/cur/' \
          | while IFS= read -r f; do
              [ -f "$f" ] || continue
              flags="''${f##*:2,}"
              case "$flags" in *S*) ;; *) continue ;; esac
              base="''${f%:2,*}"
              newflags="''${flags//S/}"
              mv "$f" "''${base}:2,''${newflags}"
            done
        # Update notmuch DB with the renames
        ${pkgs.notmuch}/bin/notmuch new --quiet 2>/dev/null || true
      '';
    };
  };
}
