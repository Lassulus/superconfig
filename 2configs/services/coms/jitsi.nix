{ pkgs, ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8043"
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

  services.prosody.extraPluginPaths =
    let
      prosody-contrib-plugins = pkgs.fetchFromGitHub {
        owner = "jitsi-contrib";
        repo = "prosody-plugins";
        rev = "v20250923";
        sha256 = "sha256-sq33ATYkZWF+ASR4IZbTGrkGWwRT+xpPMuARLSdxoMU=";
      };
    in
    [ "${prosody-contrib-plugins}/event_sync" ];

  # The first argument needs to be a valid domain name (no underscores) and a subdomain
  # of a virtual host configured in prosody (`services.prosody.virtualHosts`).
  # The second argument is the name of the module which should be found in the top level
  # of a plugin directory.
  services.prosody.extraConfig = ''
    Component "numtide-event-sync.jitsi.lassul.us" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://jitsi-presence.numtide.com"

    Component "pinpox-event-sync.jitsi.lassul.us" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://matrixpresence.0cx.de:8227"

    Component "pinpox2-event-sync.jitsi.lassul.us" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://matrixpresence.0cx.de:8226"
  '';

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
