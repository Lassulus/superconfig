{ self, config, lib, pkgs, ... }: let

  to = lib.concatStringsSep "," [
    "lass@green.r"
  ];

  mails = import "${config.krebs.secret.directory}/mails.nix"; # todo make this pure somehow

in {
  imports = [
    self.inputs.stockholm.nixosModules.exim-smarthost
  ];
  environment.systemPackages = [ pkgs.review-mail-queue ];

  krebs.exim-smarthost = {
    enable = true;
    dkim = [
      { domain = "lassul.us"; }
    ];
    ssl_cert = "/var/lib/acme/mail.lassul.us/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.lassul.us/key.pem";
    primary_hostname = "lassul.us";
    sender_domains = [
      "lassul.us"
    ];
    relay_from_hosts = map (host: host.nets.retiolum.ip6.addr) [
      config.krebs.hosts.aergia
      config.krebs.hosts.blue
      config.krebs.hosts.coaxmetal
      config.krebs.hosts.green
      config.krebs.hosts.mors
      config.krebs.hosts.xerxes
    ];
    internet-aliases = map (from: { inherit from to; }) mails ++ [
    ];
    system-aliases = [
      { from = "mailer-daemon"; to = "postmaster"; }
      { from = "postmaster"; to = "root"; }
      { from = "nobody"; to = "root"; }
      { from = "hostmaster"; to = "root"; }
      { from = "usenet"; to = "root"; }
      { from = "news"; to = "root"; }
      { from = "webmaster"; to = "root"; }
      { from = "www"; to = "root"; }
      { from = "ftp"; to = "root"; }
      { from = "abuse"; to = "root"; }
      { from = "noc"; to = "root"; }
      { from = "security"; to = "root"; }
      { from = "root"; to = "lass"; }
    ];
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport smtp"; target = "ACCEPT"; }
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
