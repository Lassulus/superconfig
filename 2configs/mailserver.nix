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
    runtimeInputs = with pkgs; [
      coreutils
      mkpasswd
      pwgen
    ];
    script = ''
      pwgen -s 32 1 > "$out/bot-mail-password"
      mkpasswd -sm bcrypt < "$out/bot-mail-password" > "$out/bot-mail-password-hash"
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
    "z /var/vmail 0750 virtualMail virtualMail -"
    "z /var/vmail/lassul.us 0750 virtualMail virtualMail -"
    "z /var/vmail/lassul.us/lass 0750 virtualMail virtualMail -"
    "Z /var/vmail/lassul.us/lass/mail 0770 virtualMail virtualMail -"
  ];

  # notmuch + muchsync + msmtp for CLI mail access
  environment.systemPackages = [
    self.packages.${pkgs.system}.notmuch
    pkgs.muchsync
    pkgs.msmtp
  ];
}
