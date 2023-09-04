{ config, lib, pkgs, ... }: let

  format-github-message = pkgs.writeDashBin "format-github-message" ''
    set -efu
    export PATH=${lib.makeBinPath [
      pkgs.jq
    ]}
    INPUT=$(jq -c .)
    if $(printf '%s' "$INPUT" | jq 'has("issue") or has("pull_request")'); then
      ${write_to_irc} "$(printf '%s' "$INPUT" | jq -r '
        "\(.action): " +
        "[\(.issue.title // .pull_request.title)] " +
        "\(.comment.html_url // .issue.html_url // .pull_request.html_url) "
      ')"
    fi
  '';

  write_to_irc = pkgs.writeDash "write_to_irc" ''
    ${pkgs.curl}/bin/curl -fsSv http://localhost:44001 \
      -H content-type:application/json \
      -d "$(${pkgs.jq}/bin/jq -n \
        --arg text "$1" '{
          command:"PRIVMSG",
          params:["#fysi",$text]
        }'
      )"
  '';

in {
  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-p tcp --dport 44002"; target = "ACCEPT"; }
  ];
  krebs.reaktor2.fysiweb-github = {
    hostname = "irc.libera.chat";
    port = "6697";
    useTLS = true;
    nick = "fysiweb-github";
    API.listen = "inet://127.0.0.1:44001";
    plugins = [
      {
        plugin = "register";
        config = {
          channels = [
            "#fysi"
          ];
        };
      }
    ];
  };
  krebs.htgen.fysiweb-github = {
    port = 44002;
    user = {
      name = "reaktor2-fysiweb-github";
    };
    script = ''. ${pkgs.writeDash "github-irc" ''
      set -xefu
      case "$Method $Request_URI" in
        "POST /")
          payload=$(head -c "$req_content_length")
          printf '%s' "$payload" | ${format-github-message}/bin/format-github-message
          printf 'HTTP/1.1 200 OK\r\n'
          printf 'Connection: close\r\n'
          printf '\r\n'
          exit
        ;;
      esac
    ''}'';
  };
}
