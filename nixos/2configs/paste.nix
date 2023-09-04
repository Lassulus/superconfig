{ config, pkgs, ... }:

{
  services.nginx.virtualHosts.cyberlocker = {
    serverAliases = [ "c.r" ];
    locations."/".extraConfig = ''
      client_max_body_size 4G;
      proxy_set_header Host $host;
      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.cyberlocker.port};
    '';
    extraConfig = ''
      add_header Access-Control-Allow-Origin * always;
      add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
    '';
  };
  services.nginx.virtualHosts.paste = {
    serverAliases = [ "p.r" ];
    locations."/".extraConfig = ''
      client_max_body_size 4G;
      proxy_set_header Host $host;
      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.paste.port};
    '';
    locations."/image".extraConfig = /* nginx */ ''
      client_max_body_size 40M;

      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.imgur.port};
      proxy_pass_header Server;
    '';
    extraConfig = ''
      add_header 'Access-Control-Allow-Origin' '*';
      add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
    '';
  };
  services.nginx.virtualHosts."c.krebsco.de" = {
    enableACME = true;
    addSSL = true;
    serverAliases = [ "c.krebsco.de" ];
    locations."/".extraConfig = ''
      if ($request_method != GET) {
        return 403;
      }
      proxy_set_header Host $host;
      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.cyberlocker.port};
    '';
    extraConfig = ''
      add_header Access-Control-Allow-Origin * always;
      add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
    '';
  };
  services.nginx.virtualHosts."p.krebsco.de" = {
    enableACME = true;
    addSSL = true;
    serverAliases = [ "p.krebsco.de" ];
    locations."/".extraConfig = ''
      if ($request_method = 'OPTIONS') {
        return 204;
      }
      client_max_body_size 4G;
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.paste.port};
    '';
    locations."/form".extraConfig = ''
      client_max_body_size 4G;
      proxy_set_header Host $host;
      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.paste-form.port};
    '';
    locations."/image".extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;

      proxy_pass http://127.0.0.1:${toString config.krebs.htgen.imgur.port};
      proxy_pass_header Server;
    '';
    extraConfig = ''
      add_header Access-Control-Allow-Headers Authorization always;
      add_header Access-Control-Allow-Origin * always;
      add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
    '';
  };

  krebs.htgen.paste = {
    port = 9081;
    script = /* sh */ ''
      (. ${pkgs.htgen-paste}/bin/htgen-paste)
    '';
  };

  systemd.services.paste-gc = {
    startAt = "daily";
    serviceConfig = {
      ExecStart = ''
        ${pkgs.findutils}/bin/find /var/lib/htgen-paste/items -type f -mtime '+30' -exec rm {} \;
      '';
      User = "htgen-paste";
    };
  };

  krebs.htgen.paste-form = {
    port = 7770;
    script = /* sh */ ''
      export PATH=${makeBinPath [
        pkgs.curl
        pkgs.gnused
      ]}:$PATH
      (. ${pkgs.writeScript "paste-form" ''
        case "$Method" in
          'POST')
            ref=$(head -c $req_content_length | sed '0,/^\r$/d;$d' | curl -fSs --data-binary @- https://p.krebsco.de | sed '1d;s/^http:/https:/')

            printf 'HTTP/1.1 200 OK\r\n'
            printf 'Content-Type: text/plain; charset=UTF-8\r\n'
            printf 'Server: %s\r\n' "$Server"
            printf 'Connection: close\r\n'
            printf 'Content-Length: %d\r\n' $(expr ''${#ref} + 1)
            printf '\r\n'
            printf '%s\n' "$ref"

            exit
          ;;
        esac
      ''})
    '';
  };
  krebs.htgen.imgur = {
    port = 7771;
    script = /* sh */ ''
      (. ${pkgs.htgen-imgur}/bin/htgen-imgur)
    '';
  };
  krebs.htgen.cyberlocker = {
    port = 7772;
    script = /* sh */ ''
      (. ${pkgs.htgen-cyberlocker}/bin/htgen-cyberlocker)
    '';
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i retiolum -p tcp --dport 80"; target = "ACCEPT";}
  ];
}
