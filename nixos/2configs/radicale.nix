{ config, ... }:

{
  services.radicale = {
    enable = true;
    config = ''
      [server]
      hosts = 0.0.0.0:5555
      [auth]
      type = htpasswd
      htpasswd_filename = ${config.krebs.secret.directory}/radicale.htpasswd
      htpasswd_encryption = plain
    '';
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i retiolum -p tcp --dport 5555"; target = "ACCEPT"; }
    { predicate = "-i wiregrill -p tcp --dport 5555"; target = "ACCEPT"; }
  ];
  #services.nginx.virtualHosts."lassul.us".locations."/radicale/".extraConfig = ''
  #  proxy_pass        http://localhost:5555/; # The / is important!
  #  proxy_set_header  X-Script-Name /radicale;
  #  proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
  #  proxy_pass_header Authorization;
  #'';
}
