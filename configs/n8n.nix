{
  ...
}:
{
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment.N8N_SECURE_COOKIE = "false";
  };

  networking.firewall.interfaces.retiolum.allowedTCPPorts = [ 5678 ];
  networking.firewall.interfaces.wiregrill.allowedTCPPorts = [ 5678 ];
}
