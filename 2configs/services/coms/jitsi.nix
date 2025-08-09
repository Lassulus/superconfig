{ pkgs, ... }:
let

  prosody-contrib-plugins = pkgs.fetchFromGitHub {
    owner = "jitsi-contrib";
    repo = "prosody-plugins";
    rev = "v20230929";
    sha256 = "sha256-1Lmj+ZWqZRRvHVgNDXXEqH2DwhE7TwP0gktjihJCg1g=";
  };

in
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
      startAudioOnly = false; # check if webcams work nicer with that
      channelLastN = 4;
      stunServers = [
        # - https://www.kuketz-blog.de/jitsi-meet-server-einstellungen-fuer-einen-datenschutzfreundlichen-betrieb/
        { urls = "turn:turn.matrix.org:3478?transport=udp"; }
        { urls = "turn:turn.matrix.org:3478?transport=tcp"; }
      ];
      constraints.video.height = {
        ideal = 720;
        max = 1080;
        min = 240;
      };
      remoteVideoMenu.disabled = false;
      breakoutRooms.hideAddRoomButton = false;
      maxFullResolutionParticipants = 1;
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
      GENERATE_ROOMNAMES_ON_WELCOME_PAGE = false;
      DISABLE_PRESENCE_STATUS = true;
    };
  };

  services.nginx.virtualHosts."meet.lassul.us" = {
    enableACME = true;
    addSSL = true;
    locations."/".return = "301 https://jitsi.lassul.us$request_uri";
  };

  services.jitsi-videobridge = {
    config.videobridge = {
      cc.assumed-bandwidth-limit = "1000 Mbps";
    };
  };

  services.prosody.package = pkgs.prosody.override {
    withExtraLuaPackages =
      p: with p; [
        # required for muc_breakout_rooms
        cjson
      ];
  };

  services.prosody.extraPluginPaths = [ "${prosody-contrib-plugins}/event_sync" ];
  services.prosody.extraModules = [
    "admin_shell"
    "event_sync"
  ];
  services.prosody.extraConfig = ''
    Component "event_sync.numtide" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://jitsi-presence.numtide.com"

    Component "event_sync.pinpox" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://matrixpresence.0cx.de:8227"

    Component "event_sync.pinpox2" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://matrixpresence.0cx.de:8226"
  '';

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport 4443";
      target = "ACCEPT";
    }
    {
      predicate = "-p udp --dport 10000";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport 10000";
      target = "ACCEPT";
    }
  ];
}
