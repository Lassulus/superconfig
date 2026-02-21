{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let

  to = lib.concatStringsSep "," [
    "lass@green.r"
    "bot"
  ];

  # Keep a minimal alias list for the ACL; the catchall router handles the rest
  mails = [
    "lassulus@lassul.us"
  ];

in
{
  imports = [
    self.inputs.stockholm.nixosModules.exim-smarthost
  ];

  clan.core.vars.generators."lassul.us-dkim" = {
    files."lassul.us.dkim.priv" = { };
    files."lassul.us.dkim.pub".secret = false;
    migrateFact = "lassul.us-dkim";
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    script = ''
      openssl genrsa -out "$out"/lassul.us.dkim.priv 2048
      openssl rsa -in "$out"/lassul.us.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$out"/lassul.us.dkim.pub
    '';
  };

  krebs.exim-smarthost = {
    enable = true;
    dkim = [
      {
        domain = "lassul.us";
        private_key = config.clan.core.vars.generators."lassul.us-dkim".files."lassul.us.dkim.priv".path;
      }
    ];
    ssl_cert = "/var/lib/acme/mail.lassul.us/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.lassul.us/key.pem";
    primary_hostname = "lassul.us";
    sender_domains = [
      "lassul.us"
    ];
    relay_from_hosts = map (host: host.nets.retiolum.ip6.addr) [
      config.krebs.hosts.aergia
      config.krebs.hosts.ignavia
      config.krebs.hosts.coaxmetal
      config.krebs.hosts.green
      config.krebs.hosts.mors
    ];
    internet-aliases = map (from: { inherit from to; }) mails ++ [
    ];

    # Catchall: redirect any unmatched @lassul.us mail
    # This runs after internet_aliases (which handles the explicit list)
    # and after system_aliases, but before local_user would reject unknown users.
    extraRouters = ''
      catchall_lassulus:
        debug_print = "R: catchall for $local_part@$domain"
        driver = redirect
        domains = lassul.us
        data = ${to}
        no_more
    '';

    system-aliases = [
      {
        from = "mailer-daemon";
        to = "postmaster";
      }
      {
        from = "postmaster";
        to = "root";
      }
      {
        from = "nobody";
        to = "root";
      }
      {
        from = "hostmaster";
        to = "root";
      }
      {
        from = "usenet";
        to = "root";
      }
      {
        from = "news";
        to = "root";
      }
      {
        from = "webmaster";
        to = "root";
      }
      {
        from = "www";
        to = "root";
      }
      {
        from = "ftp";
        to = "root";
      }
      {
        from = "abuse";
        to = "root";
      }
      {
        from = "noc";
        to = "root";
      }
      {
        from = "security";
        to = "root";
      }
      {
        from = "root";
        to = "lass";
      }
    ];
  };
  # msmtp for local submission via SSH (connects to localhost:25)
  environment.systemPackages = [ pkgs.msmtp ];

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport smtp";
      target = "ACCEPT";
    }
  ];

  security.acme.certs."mail.lassul.us" = {
    group = "lasscert";
    webroot = "/var/lib/acme/acme-challenge";
  };
  users.groups.lasscert.members = [
    "dovecot2"
    "exim"
    "nginx"
  ];
}
