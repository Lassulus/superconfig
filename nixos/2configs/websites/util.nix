{ lib, pkgs, ... }:

with lib;

rec {

  ssl = domains :
    let
      domain = head domains;
    in {
    };

  servePage = domains:
    let
      domain = head domains;
    in {
      services.nginx.virtualHosts.${domain} = {
        enableACME = true;
        addSSL = true;
        serverAliases = domains;
        locations."/".extraConfig = ''
          root /srv/http/${domain};
        '';
      };
    };

  servephpBB = domains:
    let
      domain = head domains;

    in {
      services.nginx.virtualHosts."${domain}" = {
        serverAliases = domains;
        extraConfig = ''
          index index.php;
          root /srv/http/${domain}/;
          access_log /tmp/nginx_acc.log;
          error_log /tmp/nginx_err.log;
          error_page 404 /404.html;
          error_page 500 502 503 504 /50x.html;
          client_max_body_size 100m;
        '';
        locations."/".extraConfig = ''
          try_files $uri $uri/ /index.php?$args;
        '';
        locations."~ \.php(?:$|/)".extraConfig =  ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_param PATH_INFO $fastcgi_path_info;
          fastcgi_param HTTPS on;
          fastcgi_param modHeadersAvailable true; #Avoid sending the security headers twice
          fastcgi_pass unix:/srv/http/${domain}/phpfpm.pool;
          fastcgi_intercept_errors on;
        '';
        #Directives to send expires headers and turn off 404 error logging.
        locations."~* ^.+\.(xml|ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|css|rss|atom|js|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$".extraConfig = ''
          access_log off;
          log_not_found off;
          expires max;
        '';
      };
      services.phpfpm.pools."${domain}" = {
        user = "nginx";
        group = "nginx";
        extraConfig = ''
          listen = /srv/http/${domain}/phpfpm.pool
          pm = dynamic
          pm.max_children = 25
          pm.start_servers = 5
          pm.min_spare_servers = 3
          pm.max_spare_servers = 20
          listen.owner = nginx
          listen.group = nginx
          php_admin_value[error_log] = 'stderr'
          php_admin_flag[log_errors] = on
          catch_workers_output = yes
        '';
      };
    };

  serveOwncloud = domains:
    let
      domain = head domains;
      legacy_nixpkgs = import (builtins.fetchTarball "https://github.com/nixos/nixpkgs/archive/22.05.tar.gz") {};
    in {
      services.nginx.virtualHosts."${domain}" = {
        enableACME = true;
        addSSL = true;
        serverAliases = domains;
        extraConfig = ''
          # Add headers to serve security related headers
          add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
          add_header X-Content-Type-Options nosniff;
          add_header X-Frame-Options "SAMEORIGIN";
          add_header X-XSS-Protection "1; mode=block";
          add_header X-Robots-Tag none;
          add_header X-Download-Options noopen;
          add_header X-Permitted-Cross-Domain-Policies none;

          # Path to the root of your installation
          root /srv/http/${domain}/;
          # set max upload size
          client_max_body_size 10G;
          fastcgi_buffers 64 4K;
          fastcgi_read_timeout 120;

          # Disable gzip to avoid the removal of the ETag header
          gzip off;

          # Uncomment if your server is build with the ngx_pagespeed module
          # This module is currently not supported.
          #pagespeed off;

          index index.php;
          error_page 403 /core/templates/403.php;
          error_page 404 /core/templates/404.php;

          rewrite ^/.well-known/carddav /remote.php/carddav/ permanent;
          rewrite ^/.well-known/caldav /remote.php/caldav/ permanent;

          # The following 2 rules are only needed for the user_webfinger app.
          # Uncomment it if you're planning to use this app.
          rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
          rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;
        '';
        locations."/robots.txt".extraConfig = ''
          allow all;
          log_not_found off;
          access_log off;
        '';
        locations."~ ^/(build|tests|config|lib|3rdparty|templates|data)/".extraConfig = ''
          deny all;
        '';

        locations."~ ^/(?:autotest|occ|issue|indie|db_|console)".extraConfig =  ''
          deny all;
        '';

        locations."/".extraConfig = ''
          rewrite ^/remote/(.*) /remote.php last;
          rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;
          try_files $uri $uri/ =404;
        '';

        locations."~ \.php(?:$|/)".extraConfig =  ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_param PATH_INFO $fastcgi_path_info;
          fastcgi_param HTTPS on;
          fastcgi_param modHeadersAvailable true; #Avoid sending the security headers twice
          fastcgi_pass unix:/srv/http/${domain}/phpfpm.pool;
          fastcgi_intercept_errors on;
        '';

        # Adding the cache control header for js and css files
        # Make sure it is BELOW the location ~ \.php(?:$|/) { block
        locations."~* \.(?:css|js)$".extraConfig = ''
          add_header Cache-Control "public, max-age=7200";
          # Add headers to serve security related headers
          add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
          add_header X-Content-Type-Options nosniff;
          add_header X-Frame-Options "SAMEORIGIN";
          add_header X-XSS-Protection "1; mode=block";
          add_header X-Robots-Tag none;
          # Optional: Don't log access to assets
          access_log off;
        '';
        # Optional: Don't log access to other assets
        locations."~* \.(?:jpg|jpeg|gif|bmp|ico|png|swf)$".extraConfig = ''
          access_log off;
        '';
      };
      services.phpfpm.pools."${domain}" = {
        user = "nginx";
        group = "nginx";
        phpPackage = legacy_nixpkgs.php74;
        extraConfig = ''
          listen = /srv/http/${domain}/phpfpm.pool
          pm = dynamic
          pm.max_children = 32
          pm.max_requests = 500
          pm.start_servers = 2
          pm.min_spare_servers = 2
          pm.max_spare_servers = 5
          listen.owner = nginx
          listen.group = nginx
          php_admin_value[error_log] = 'stderr'
          php_admin_flag[log_errors] = on
          catch_workers_output = yes
        '';
      };
    };

  serveWordpress = domains:
    let
      domain = head domains;

    in {
      services.nginx.virtualHosts."${domain}" = {
        enableACME = true;
        forceSSL = true;
        serverAliases = domains;
        extraConfig = ''
          root /srv/http/${domain}/;
          index index.php;
          access_log /tmp/nginx_acc.log;
          error_log /tmp/nginx_err.log;
          error_page 404 /404.html;
          error_page 500 502 503 504 /50x.html;
          client_max_body_size 100m;
        '';
        locations."/".extraConfig = ''
          try_files $uri $uri/ /index.php?$args;
        '';
        locations."~ \.php$".extraConfig = ''
          fastcgi_pass unix:/srv/http/${domain}/phpfpm.pool;
          fastcgi_read_timeout 120;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
        #Directives to send expires headers and turn off 404 error logging.
        locations."~* ^.+\.(xml|ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|css|rss|atom|js|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$".extraConfig = ''
          access_log off;
          log_not_found off;
          expires max;
        '';
        locations."/nb".extraConfig = ''
          index index.html;
        '';
      };
      services.phpfpm.pools."${domain}" = {
        user = "nginx";
        group = "nginx";
        extraConfig = ''
          listen = /srv/http/${domain}/phpfpm.pool
          pm = dynamic
          pm.max_children = 25
          pm.start_servers = 5
          pm.min_spare_servers = 3
          pm.max_spare_servers = 20
          listen.owner = nginx
          listen.group = nginx
          php_admin_value[error_log] = 'stderr'
          php_admin_flag[log_errors] = on
          catch_workers_output = yes
        '';
      };
    };

}
