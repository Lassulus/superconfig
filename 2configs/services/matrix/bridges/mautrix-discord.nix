{ ... }:
{
  services.mautrix-discord = {
    enable = true;
    registerToSynapse = true;
    settings = {
      homeserver = {
        address = "http://[::1]:8008";
        domain = "lassul.us";
      };
      # `settings.{homeserver,appservice,bridge,logging}` use `types.attrs` with
      # full defaults, so this is a shallow merge — set keys override the
      # default's same-level keys, but nested subtrees we redefine (database,
      # bot, encryption, permissions) replace the default's subtree wholesale.
      appservice = {
        address = "http://127.0.0.1:29334";
        hostname = "127.0.0.1";
        port = 29334;
        database = {
          type = "postgres";
          uri = "postgres:///mautrix-discord?host=/run/postgresql";
        };
        id = "discord";
        bot = {
          username = "discordbot";
          displayname = "Discord bridge bot";
          avatar = "mxc://maunium.net/nIdEykemnwdisvHbpxflpDlC";
        };
        ephemeral_events = true;
      };
      bridge = {
        username_template = "discord_{{.}}";
        displayname_template = "{{if .Webhook}}Webhook{{else}}{{or .GlobalName .Username}}{{if .Bot}} (bot){{end}}{{end}} (D)";
        delivery_receipts = false;
        message_status_events = false;
        encryption = {
          allow = false;
          default = false;
          require = false;
        };
        permissions = {
          "lassul.us" = "user";
          "@lassulus:lassul.us" = "admin";
        };
      };
    };
  };

  services.postgresql = {
    ensureDatabases = [ "mautrix-discord" ];
    ensureUsers = [
      {
        name = "mautrix-discord";
        ensureDBOwnership = true;
      }
    ];
  };
}
