#!/bin/sh
# needs in path:
#   curl gnugrep jq
# creates and manages $PWD/state
set -xeuf

send_reaktor(){
  # usage: send_reaktor "text"
  echo "send_reaktor: $1"
  curl -fsS "http://localhost:$REAKTOR_PORT" \
      -H content-type:application/json \
      -d "$(jq -n \
        --arg text "$1" \
        --arg channel "$IRC_CHANNEL" \
        '{
          command:"PRIVMSG",
          params:[$channel,$text]
        }'
      )"
}

live=$(shuf -n1 <<EOF
Binärgewitter Liveshow hat begonnen! http://stream.radiotux.de:8000/binaergewitter.mp3
EOF
)

offline=$(shuf -n1 <<EOF
Live stream vorbei
EOF
)
error=$(shuf -n1 <<EOF
something went wrong
EOF
)

if curl -Ss http://stream.radiotux.de:8000 | grep -q 'Mount Point /binaergewitter'; then
  state='live'
else
  state='offline'
fi
prevstate=$(cat state ||:)

if test "$state" == "$(cat state)";then
  #echo "current and last state is the same ($state), doing nothing"
  :
else
  echo "API state and last state differ ( '$state' != '$prevstate')"
  if test "$state" == 'live';then
    send_reaktor "$live"
  elif test "$state" == 'offline';then
    send_reaktor "$offline"
  else
    send_reaktor "$error"
  fi
  echo 'updating state'
  printf "%s" "$state" > state
fi
