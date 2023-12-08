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

  services.prosody.extraConfig = ''
    Component "event_sync.meet.mydomain.com" "event_sync_component"
        muc_component = "conference.meet.mydomain.com"
        breakout_component = "breakout.meet.mydomain.com"

        api_prefix = "https://jitsi-presence.numtide.com"

        --- The following are all optional
        api_timeout = 3  -- timeout if API does not respond within 3s
        api_retry_count = 1  -- retry up to 1 times
        api_retry_delay = 5  -- wait 5s between retries

        -- change retry rules so we also retry if endpoint returns HTTP 408
        api_should_retry_for_code = function (code)
            return code >= 500 or code == 408
        end

        -- Optionally include total_dominant_speaker_time (milliseconds) in payload for occupant-left and room-destroyed
        include_speaker_stats = true
  '';

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 4443"; target = "ACCEPT"; }
    { predicate = "-p udp --dport 10000"; target = "ACCEPT"; }
    { predicate = "-p tcp --dport 10000"; target = "ACCEPT"; }
  ];
}
