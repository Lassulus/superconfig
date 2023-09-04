{ pkgs }:
pkgs.writers.writeDashBin "dls" ''
  set -efux
  SESSION_ID=$(
    curl -Ss -d '{}' http://yellow.r:9091/transmission/rpc -v -o /dev/null 2>&1 |
      grep -oP '(?<=X-Transmission-Session-Id: )\w+'
  )
  ${pkgs.curl}/bin/curl -Ss \
    http://yellow.r:9091/transmission/rpc \
    -H "X-Transmission-Session-Id: $SESSION_ID" \
    -d '{"arguments":{"fields":["errorString","eta","isFinished","name","sizeWhenDone","status"]},"method":"torrent-get","tag":4}' |
    jq .
''
