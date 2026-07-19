{ config, ... }:
{
  imports = [ ./module.nix ];
  clan.hedgedoc.domain = "pad.lassul.us";

  # GitHub login (https://github.com/settings/applications/2352617)
  clan.core.vars.generators.hedgedoc-github-auth = {
    files."hedgedoc.env" = { };
    prompts."hedgedoc.env" = {
      description = ''
        goto https://github.com/settings/applications/2352617 and paste the data in the following format:
        GITHUB_CLIENT_ID=...
        GITHUB_CLIENT_SECRET=...
      '';
      type = "multiline";
    };
  };

  # pocket-id (id.lassul.us) OIDC login, offered alongside GitHub. The endpoints
  # are public config; only the client id/secret are secret (clan vars below).
  # Register the client in pocket-id with callback URL:
  #   https://pad.lassul.us/auth/oauth2/callback
  services.hedgedoc.settings.oauth2 = {
    providerName = "pocket-id";
    authorizationURL = "https://id.lassul.us/authorize";
    tokenURL = "https://id.lassul.us/api/oidc/token";
    userProfileURL = "https://id.lassul.us/api/oidc/userinfo";
    scope = "openid email profile";
    userProfileUsernameAttr = "preferred_username";
    userProfileDisplayNameAttr = "name";
    userProfileEmailAttr = "email";
  };
  clan.core.vars.generators.hedgedoc-pocket-id = {
    files."pocket-id.env" = { };
    prompts."pocket-id.env" = {
      description = ''
        Register an OIDC client in pocket-id (https://id.lassul.us):
          name:         HedgeDoc
          callback URL: https://pad.lassul.us/auth/oauth2/callback
        Generate a client secret, then paste:
        CMD_OAUTH2_CLIENT_ID=...
        CMD_OAUTH2_CLIENT_SECRET=...
      '';
      type = "multiline";
    };
  };

  # GitHub session-secret env comes from module.nix; append both external-auth
  # env files here (systemd merges the EnvironmentFile lists).
  systemd.services.hedgedoc.serviceConfig.EnvironmentFile = [
    config.clan.core.vars.generators.hedgedoc-github-auth.files."hedgedoc.env".path
    config.clan.core.vars.generators.hedgedoc-pocket-id.files."pocket-id.env".path
  ];
}
