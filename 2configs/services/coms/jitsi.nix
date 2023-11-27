{

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
      entity-expiration.timeout = "10 minutes";
    };
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 4443"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 10000"; target = "ACCEPT"; }
    { predicate = "-p tcp --dport 10000"; target = "ACCEPT"; }
  ];
}
