{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "acme@lassul.us";

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    enableReload = true;

    # avoid nixpkgs nginx's /tmp/nginx_* compile-time defaults: under
    # systemd PrivateTmp they don't survive a host `rm -rf /tmp/*`.
    appendHttpConfig = ''
      client_body_temp_path /var/cache/nginx/client_body;
      proxy_temp_path /var/cache/nginx/proxy;
      fastcgi_temp_path /var/cache/nginx/fastcgi;
      uwsgi_temp_path /var/cache/nginx/uwsgi;
      scgi_temp_path /var/cache/nginx/scgi;
    '';

    virtualHosts.default = {
      default = true;
      locations."/".extraConfig = ''
        return 404;
      '';
      locations."= /etc/os-release".extraConfig = ''
        default_type text/plain;
        alias /etc/os-release;
      '';
      locations."~ ^/.well-known/acme-challenge/".root = "/var/lib/acme/acme-challenge";
    };
  };
}
