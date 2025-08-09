{ config, ... }:
{
  imports = [ ./module.nix ];
  clan.hedgedoc.domain = "pad.lassul.us";
  clan.core.vars.generators.hedgedoc-github-auth = {
    files."hedgedoc.env" = { };
    migrateFact = "hedgedoc-github-auth";
    prompts.env = {
      description = ''
        goto https://github.com/settings/applications/2352617 and paste the data in the following format:
        GITHUB_CLIENT_ID=...
        GITHUB_CLIENT_SECRET=...
      '';
      type = "multiline";
    };
    script = ''
      cp "$prompts"/env "$out"/hedgedoc.env
    '';
  };
  # https://github.com/settings/applications/2352617
  systemd.services.hedgedoc.serviceConfig.EnvironmentFile = [
    config.clan.core.vars.generators.hedgedoc-github-auth.files."hedgedoc.env".path
  ];
}
