{
  self,
  config,
  pkgs,
  ...
}:
let
  send_to_radio = pkgs.writers.writeDashBin "send_to_radio" ''
    ${pkgs.vorbis-tools}/bin/oggenc - |
      ${pkgs.cyberlocker-tools}/bin/cput news.ogg
    ${pkgs.curl}/bin/curl -fSs -X POST http://localhost:8002/newsshow
  '';

  gc_news = pkgs.writers.writeDashBin "gc_news" ''
    set -xefu
    export TZ=UTC #workaround for jq parsing wrong timestamp
    ${pkgs.coreutils}/bin/cat $HOME/news | ${pkgs.jq}/bin/jq -cs 'map(select((.to|fromdateiso8601) > now)) | .[]' > $HOME/bla-news.tmp
    ${pkgs.coreutils}/bin/mv $HOME/bla-news.tmp $HOME/news
  '';

  get_current_news = pkgs.writers.writeDashBin "get_current_news" ''
    set -xefu
    export TZ=UTC #workaround for jq parsing wrong timestamp
    ${pkgs.coreutils}/bin/cat $HOME/news | ${pkgs.jq}/bin/jq -rs '
      sort_by(.priority) |
      map(select(
        ((.to | fromdateiso8601) > now) and
        (.from|fromdateiso8601) < now) |
        .text
      ) | .[]'
  '';

  newsshow =
    pkgs.writers.writeDashBin "newsshow" # sh
      ''
        cat << EOF
        hello crabpeople!
        $(${pkgs.ddate}/bin/ddate +'Today is %{%A, the %e of %B%}, %Y. %N%nCelebrate %H')
        It is $(date --utc +%H) o clock U.T.C.
        todays news:
        $(get_current_news)
        $(gc_news)
        EOF
      '';
in
{
  systemd.services.newsshow = {
    path = [
      newsshow
      send_to_radio
      gc_news
      get_current_news
      pkgs.retry
    ];
    script = ''
      set -efu
      retry -t 5 -d 10 -- newsshow |
        retry -t 5 -d 10 -- /run/current-system/sw/bin/tts |
        retry -t 5 -d 10 -- send_to_radio
    '';
    startAt = "*:00:00";
    serviceConfig = {
      User = "radio-news";
    };
  };

  security.acme.certs."radio-news.r".server = config.krebs.ssl.acmeURL;

  services.nginx.virtualHosts."radio-news.r" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:7999";
      proxyWebsockets = true;
      extraConfig = ''
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
      '';
    };
  };
  imports = [
    self.inputs.stockholm.nixosModules.htgen
    ./tts.nix
  ];
  krebs.htgen.news = {
    port = 7999;
    user = {
      name = "radio-news";
    };
    script = ''. ${pkgs.writers.writeDash "htgen-news" ''
      set -xefu
      case "''${Method:-GET} $Request_URI" in
        "GET /")
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          cat "$HOME"/news | jq -sc .
          exit
        ;;
        "POST /")
          payload=$(head -c "$req_content_length")
          printf '%s' "$payload" | jq 'has("from") and has("to") and has("text")' >&2
          printf '%s' "$payload" | jq -c '{ from: .from, to: .to, text: .text, priority: (.priority // 0)}' >> "$HOME"/news
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          exit
        ;;
      esac
    ''}'';
  };

  # debug
  environment.systemPackages = [
    send_to_radio
    newsshow
    get_current_news
    gc_news
  ];
}
