{
  # Public door to the Hermes API server on coaxmetal (machines/coaxmetal/hermes.nix).
  # This is what the WakeHermesClaw app on massulus points at when it is not
  # on retiolum: the assistant button posts to /v1/chat/completions here.
  #
  # SECURITY: behind this vhost sits an agent with terminal tools and, through
  # the herdr wrapper, code execution as lass. The gateway's only check on
  # this lane is the API_SERVER_KEY bearer token — there is no per-user
  # allowlist like MATRIX_ALLOWED_USERS on the Matrix lane. So the token is a
  # root-equivalent credential for that laptop; rotate it by regenerating the
  # hermes-api var, and expect to see internet background noise in the access
  # log (unauthenticated requests get 401 from hermes itself).
  services.nginx.virtualHosts."hermes.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://coaxmetal.r:8642";
      extraConfig = ''
        # Agent turns run for minutes and /v1/chat/completions streams SSE
        # chunks the whole time. nginx's default 60s proxy_read_timeout would
        # cut a long turn off mid-answer, and its response buffering would
        # hold the stream back until the turn ended, so the phone would sit
        # silent and then dump everything at once.
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
        proxy_buffering off;
        proxy_cache off;
        # coaxmetal is a laptop: asleep or off the mesh most of the day. Fail
        # fast on connect so the app reports "unreachable" instead of hanging
        # on the assistant button.
        proxy_connect_timeout 5s;
      '';
    };
  };
}
