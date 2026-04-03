{
  self,
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.generators.archiver-jellyfin = {
    prompts.jellyfin-api-key = {
      description = "Jellyfin API key - create one in Jellyfin Dashboard -> API Keys";
      type = "hidden";
      persist = true;
    };
  };

  clan.core.vars.generators.archiver-matrix = {
    prompts.matrix-access-token = {
      description = "Matrix access token for @archiver:lassul.us - register the user on synapse, then get a token via: curl -XPOST 'https://matrix.lassul.us/_matrix/client/r0/login' -d '{\"type\":\"m.login.password\",\"user\":\"archiver\",\"password\":\"...\"}' -H 'Content-Type: application/json'";
      type = "hidden";
      persist = true;
    };

  };

  systemd.services.archiver-bot = {
    description = "Archiver Matrix Bot - requests movies via Jellyseerr";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "jellyseerr.service"
    ];
    wants = [ "network-online.target" ];

    environment = {
      MATRIX_HOMESERVER = "https://matrix.lassul.us";
      MATRIX_USER_ID = "@archiver:lassul.us";
      MATRIX_DEVICE_ID = "ARCHIVER";
      JELLYSEERR_URL = "http://localhost:5055";
      FLAX_URL = "https://flax.lassul.us";
      FLIX_URL = "https://flix.lassul.us";
      IPFS_GATEWAY_URL = "https://ipfs.lassul.us";
      JELLYFIN_URL = "http://localhost:8096";

      MEDIA_PATH_PREFIX = "/var/download/";
      IPFS_CID_MAP = "/var/lib/ipfs/cid-map.txt";
      IPFS_PATH_PREFIX = "/var/lib/ipfs/download/";
      WEBHOOK_PORT = "8099";
      STORE_PATH = "/var/lib/archiver-bot";
    };

    script = ''
      export MATRIX_ACCESS_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/matrix-access-token")"
      export JELLYSEERR_API_KEY="$(${pkgs.jq}/bin/jq -r '.main.apiKey' "$CREDENTIALS_DIRECTORY/jellyseerr-settings")"
      export RADARR_API_KEY="$(${pkgs.libxml2}/bin/xmllint --xpath 'string(//ApiKey)' "$CREDENTIALS_DIRECTORY/radarr-config")"
      export SONARR_API_KEY="$(${pkgs.libxml2}/bin/xmllint --xpath 'string(//ApiKey)' "$CREDENTIALS_DIRECTORY/sonarr-config")"
      export JELLYFIN_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/jellyfin-api-key")"
      exec ${self.packages.${pkgs.system}.archiver-bot}/bin/archiver-bot
    '';

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
      DynamicUser = true;
      StateDirectory = "archiver-bot";
      LoadCredential = [
        "matrix-access-token:${
          config.clan.core.vars.generators.archiver-matrix.files."matrix-access-token".path
        }"
        "jellyseerr-settings:/var/lib/private/jellyseerr/config/settings.json"
        "radarr-config:/var/lib/radarr/.config/Radarr/config.xml"
        "sonarr-config:/var/lib/sonarr/.config/NzbDrone/config.xml"
        "jellyfin-api-key:${
          config.clan.core.vars.generators.archiver-jellyfin.files."jellyfin-api-key".path
        }"
      ];
    };
  };
}
