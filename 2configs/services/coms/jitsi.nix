{ ... }:
{

  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8792"
  ];
  services.jitsi-meet = {
    enable = true;
    hostName = "jitsi.lassul.us";
    config = {
      enableWelcomePage = true;
      requireDisplayName = true;
      analytics.disabled = true;
      stunServers = [
        # - https://www.kuketz-blog.de/jitsi-meet-server-einstellungen-fuer-einen-datenschutzfreundlichen-betrieb/
        { urls = "turn:turn.matrix.org:3478?transport=udp"; }
        { urls = "turn:turn.matrix.org:3478?transport=tcp"; }
      ];
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
      GENERATE_ROOMNAMES_ON_WELCOME_PAGE = false;
      DISABLE_PRESENCE_STATUS = true;
      DEFAULT_REMOTE_DISPLAY_NAME = "Fellow Nixer";
    };
  };

  services.prosody.checkConfig = false;

  services.nginx.virtualHosts."meet.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/".return = "301 https://jitsi.lassul.us$request_uri";
  };

  networking.firewall.allowedTCPPorts = [
    4443
    10000
  ];
  networking.firewall.allowedUDPPorts = [ 10000 ];
}
