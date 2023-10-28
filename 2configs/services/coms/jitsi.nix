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
      # constraints.video.height = {
      #   ideal = 720;
      #   max = 1080;
      #   min = 240;
      # };
      remoteVideoMenu.disabled = false;
      breakoutRooms.hideAddRoomButton = false;
      maxFullResolutionParticipants = -1;
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
      GENERATE_ROOMNAMES_ON_WELCOME_PAGE = false;
    };
  };

  services.jitsi-videobridge = {
    config = {
      ep-connection-status.first-transfer-timeout = "5 seconds";
    };
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 4443"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 10000"; target = "ACCEPT"; }
    { predicate = "-p tcp --dport 10000"; target = "ACCEPT"; }
  ];
}
