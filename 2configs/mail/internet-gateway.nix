{ config, lib, pkgs, ... }:
{
  security.acme.certs."mail.lassul.us" = {
    group = "lasscert";
    webroot = "/var/lib/acme/acme-challenge";
  };
  users.groups.lasscert.members = [
    "exim"
    "nginx"
  ];

  krebs.exim-smarthost = {
    enable = true;
    primary_hostname = "lassul.us";
    dkim = [
      { domain = "lassul.us"; }
    ];
    ssl_cert = "/var/lib/acme/mail.lassul.us/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.lassul.us/key.pem";
    local_domains = [
      "localhost"
      "lassul.us"
      "ubikmedia.eu"
      "ubikmedia.de"
      "apanowicz.de"
      "alewis.de"
      "jarugadesign.de"
      "beesmooth.ch"
      "event-extra.de"
      "jla-trading.com"
    ];
    extraRouters = ''
      forward_lassul_us:
        driver = manualroute
        domains = lassul.us
        transport = remote_smtp
        route_list = * orange.r
        no_more

      forward_ubik:
        driver = manualroute
        domains = ubikmedia.eu:ubikmedia.de:apanowicz.de:alewis.de:jarugadesign.de:beesmooth.ch:event-extra.de:jla-trading.com
        transport = remote_smtp
        route_list = * ubik.r
        no_more
    '';
  };
}
