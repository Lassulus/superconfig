{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    openMulticastPort = true;
    settings = {
      IfName = "ygg";
      Listen = [
        "tls://[::]:37123"
      ];
      Peers = [
        "tls://neoprism.lassul.us:37123"
      ];
    };
  };
  networking.firewall.allowedTCPPorts = [ 37123 ];
  networking.firewall.allowedUDPPorts = [ 37123 ];
}
