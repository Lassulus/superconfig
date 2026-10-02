let
  domain = "parley.lassul.us";
in
{
  # parley: federated chat that speaks plain IRC. Identities are
  # nick@lassul.us; peers find this instance via the _parley._tcp.lassul.us
  # SRV record (configs/dns/lassul.us.zone).
  lass.parley = {
    enable = true;
    settings = {
      PARLEY_DOMAIN = "lassul.us";
      PARLEY_ENDPOINT = "https://${domain}";
    };
    users.lassulus.role = "admin";
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:8443";
  };

  # IRC over TLS (parleyd advertises 6697 by default)
  services.nginx.streamConfig = ''
    server {
      listen 6697 ssl;
      listen [::]:6697 ssl;
      ssl_certificate /var/lib/acme/${domain}/fullchain.pem;
      ssl_certificate_key /var/lib/acme/${domain}/key.pem;
      proxy_pass 127.0.0.1:6667;
    }
  '';
  networking.firewall.allowedTCPPorts = [ 6697 ];
}
