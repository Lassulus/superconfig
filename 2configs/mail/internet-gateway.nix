{ config, pkgs, ... }:
{
  security.acme.certs."mail.lassul.us" = {
    group = "lasscert";
    webroot = "/var/lib/acme/acme-challenge";
  };
  users.groups.lasscert.members = [
    "exim"
    "nginx"
  ];

  clan.core.vars.generators.lassul-us-dkim = {
    files."lassul.us.dkim.priv" = { };
    files."lassul.us.dkim.pub" = { };
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
    primary_hostname = "lassul.us";
    dkim = [
      {
        domain = "lassul.us";
        private_key = config.clan.core.vars.generators.lassul-us-dkim.files."lassul.us.dkim.priv".path;
      }
    ];
    ssl_cert = "/var/lib/acme/mail.lassul.us/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.lassul.us/key.pem";
    local_domains = [
      "localhost"
      "lassul.us"
    ];
    extraRouters = ''
      forward_lassul_us:
        driver = manualroute
        domains = lassul.us
        transport = remote_smtp
        route_list = * orange.r
        no_more
    '';
  };
}
