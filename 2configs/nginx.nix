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

    virtualHosts.default = {
      default = true;
      locations."= /etc/os-release".extraConfig = ''
        default_type text/plain;
        alias /etc/os-release;
      '';
      locations."~ ^/.well-known/acme-challenge/".root = "/var/lib/acme/acme-challenge";
    };
  };
}
