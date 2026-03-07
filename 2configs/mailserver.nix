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
  };

  # dovecot pre-start creates /var/vmail with 0700; widen for lass (virtualMail group)
  # POSIX ACL default ensures new files inherit lass access (needed for muchsync hardlinks)
  systemd.services.dovecot.serviceConfig.ExecStartPost = [
    "+${pkgs.coreutils}/bin/chmod 2770 /var/vmail"
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

  # Dovecot virtual mailbox + ACL-restricted shared namespace for bot
  services.dovecot2.mailPlugins.globally.enable = [
    "virtual"
    "acl"
  ];
  services.dovecot2.extraConfig =
    let
      virtualDir = pkgs.linkFarm "dovecot-virtual" [
        {
          name = "Unread/dovecot-virtual";
          path = pkgs.writeText "dovecot-virtual-unread" "*\n  unseen\n";
        }
      ];
    in
    ''
      plugin {
        acl = vfile
        acl_shared_dict = file:/var/vmail/shared-mailboxes.db
      }

      namespace shared {
        type = shared
        separator = .
        prefix = shared.%%n.
        location = maildir:/var/vmail/lassul.us/%%n/mail:LAYOUT=Maildir++
        subscriptions = no
        list = children
      }

      namespace virtual {
        prefix = virtual.
        separator = .
        location = virtual:${virtualDir}:INDEX=/var/vmail/virtual-indexes/%u
        subscriptions = no
        mailbox Unread {
          auto = subscribe
        }
      }
    '';

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
}
