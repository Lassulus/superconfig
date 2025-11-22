{ ... }:
{
  services.murmur = {
    enable = true;
    # allowHtml = false;
    bandwidth = 10000000;
    registerName = "lassul.us";
    autobanTime = 30;
    sslCert = "/var/lib/acme/lassul.us/cert.pem";
    sslKey = "/var/lib/acme/lassul.us/key.pem";
    extraConfig = ''
      opusthreshold=0
      # rememberchannelduration=10000
    '';
  };
  networking.firewall.allowedTCPPorts = [ 64738 ];
  networking.firewall.allowedUDPPorts = [ 64738 ];

  services.nginx.virtualHosts."lassul.us" = {
    enableACME = true;
  };
  security.acme.certs."lassul.us" = {
    group = "lasscert";
  };
  users.groups.lasscert.members = [
    "nginx"
    "murmur"
  ];
}
