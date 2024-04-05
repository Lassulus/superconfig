{ pkgs, ... }: let

  prosody-contrib-plugins = pkgs.fetchFromGitHub {
    owner = "jitsi-contrib";
    repo = "prosody-plugins";
    rev = "v20230929";
    sha256 = "sha256-1Lmj+ZWqZRRvHVgNDXXEqH2DwhE7TwP0gktjihJCg1g=";
  };

in {

  services.jitsi-meet = {
    enable = true;
    hostName = "jitsi.lassul.us";
    config = {
      enableWelcomePage = true;
      requireDisplayName = true;
      analytics.disabled = true;
      startAudioOnly = true;
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

  services.jitsi-videobridge = {
    config.videobridge = {
      cc.assumed-bandwidth-limit = "1000 Mbps";
      entity-expiration.timeout = "100 minutes";
    };
  };

  services.prosody.extraPluginPaths = [ "${prosody-contrib-plugins}/event_sync" ];
  services.prosody.extraModules = [ "admin_shell" "event_sync" ];
  services.prosody.extraConfig = ''
    Component "event_sync.jitsi.lassul.us" "event_sync_component"
      muc_component = "conference.jitsi.lassul.us"
      breakout_component = "breakout.jitsi.lassul.us"

      api_prefix = "http://jitsi-presence.numtide.com"
  '';

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 4443"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 10000"; target = "ACCEPT"; }
    { predicate = "-p tcp --dport 10000"; target = "ACCEPT"; }
  ];
}
