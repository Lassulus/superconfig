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
        sieveScript = ''
          require ["fileinto", "mailbox"];

          # GitHub — sort by repo from List-Id header
          if header :contains "List-Id" ".github.com" {
              if header :contains "List-Id" "nixpkgs" { fileinto :create "GitHub.nixpkgs"; }
              elsif header :contains "List-Id" "disko" { fileinto :create "GitHub.disko"; }
              elsif header :contains "List-Id" "clan-core" { fileinto :create "GitHub.clan-core"; }
              elsif header :contains "List-Id" "data-mesher" { fileinto :create "GitHub.data-mesher"; }
              elsif header :contains "List-Id" "foundation" { fileinto :create "GitHub.foundation"; }
              elsif header :contains "List-Id" "nix." { fileinto :create "GitHub.nix"; }
              elsif header :contains "List-Id" "nixos-wiki" { fileinto :create "GitHub.nixos-wiki"; }
              elsif header :contains "List-Id" "nixos-homepage" { fileinto :create "GitHub.nixos-homepage"; }
              else { fileinto :create "GitHub.other"; }
              stop;
          }

          # Gitea (clan)
          if anyof (
              header :matches "X-Gitea-*" "*",
              address :domain "From" "clan.lol"
          ) {
              fileinto :create "GitHub.clan";
              stop;
          }

          # Mailing lists — sort by List-Id
          if exists "List-Id" {
              if header :contains "List-Id" "vorstand.c-base" { fileinto :create "Lists.c-base-vorstand"; }
              elsif header :contains "List-Id" "c-base" { fileinto :create "Lists.c-base"; }
              elsif header :contains "List-Id" "afra" { fileinto :create "Lists.afra"; }
              elsif header :contains "List-Id" "soundlab" { fileinto :create "Lists.soundlab"; }
              elsif header :contains "List-Id" "nixos" { fileinto :create "Lists.nixos"; }
              elsif header :contains "List-Id" "shack" { fileinto :create "Lists.shack"; }
              elsif header :contains "List-Id" "dezentrale" { fileinto :create "Lists.dezentrale"; }
              elsif header :contains "List-Id" "dn42" { fileinto :create "Lists.dn42"; }
              elsif header :contains "List-Id" "tinc" { fileinto :create "Lists.tinc"; }
              elsif header :contains "List-Id" "wireguard" { fileinto :create "Lists.wireguard"; }
              elsif header :contains "List-Id" "retiolum" { fileinto :create "Lists.retiolum"; }
              else { fileinto :create "Lists.other"; }
              stop;
          }

          # Billing/receipts
          if anyof (
              address :domain "From" "paypal.de",
              address :domain "From" "paypal.com",
              address :domain "From" "steuerberaten.de",
              address :domain "From" "patreon.com",
              address :domain "From" "dhl.de",
              address :domain "From" "eloop.app",
              header :contains "Subject" "Rechnung",
              header :contains "Subject" "Invoice",
              header :contains "Subject" "receipt"
          ) {
              fileinto :create "Billing";
              stop;
          }

          # Newsletters (has unsubscribe but no List-Id)
          if allof (
              header :contains "List-Unsubscribe" "http",
              not exists "List-Id"
          ) {
              fileinto :create "Newsletters";
              stop;
          }

          # Everything else -> INBOX
          keep;
        '';
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

  # Firewall rules (krebs.iptables pattern, INPUT policy is DROP)
  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport smtp";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport submissions";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport submission";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport imaps";
      target = "ACCEPT";
    }
  ];

  # msmtp for local submission via SSH
  environment.systemPackages = [ pkgs.msmtp ];
}
