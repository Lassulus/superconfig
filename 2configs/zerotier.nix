{ pkgs, ... }:
{
  clan.networking.zerotier = {
    controller = {
      enable = true;
      public = false;
    };
  };
  environment.systemPackages = [
    # pkgs.zerocli
    pkgs.jq
    (pkgs.writers.writeDashBin "zt-member-ls" ''
      set -eu
      NETWORK_ID=''${NETWORK_ID:-$(zerotier-cli listnetworks -j | jq -r '.[0] | .id')}
      cat /var/lib/zerotier-one/controller.d/network/$NETWORK_ID/member/* | jq -s
    '')
    (pkgs.writers.writeDashBin "zt-member-auth" ''
      set -efux
      MEMBER_ID=$1
      if ! printf '%s' $MEMBER_ID | grep -q '^[0-9a-f]\{10\}$'; then
        echo '$MEMBER_ID is not a valid member id'
        exit 1
      fi
      URL='http://localhost:9993/controller/'
      TOKEN=''${TOKEN:-$(cat /var/lib/zerotier-one/authtoken.secret)}
      NETWORK_ID=''${NETWORK_ID:-$(zerotier-cli listnetworks -j | jq -r '.[0] | .id')}

      curl -fSs -H "X-ZT1-AUTH: $TOKEN" "$URL/network/$NETWORK_ID/member/$MEMBER_ID" -d '{"authorized": true}'
    '')
  ];
}
