{ config, ... }:
{
  imports = [ ./module.nix ];
  clan.hedgedoc.domain = "pad.lassul.us";
  clan.core.facts.services.hedgedoc-github-auth = {
    secret."hedgedoc.env" = { };
    generator.script = ''
      echo "$prompt_value" > "$secrets"/hedgedoc.env
    '';
    generator.prompt = ''
      goto https://github.com/settings/ap:qplications/2352617 and paste the data in the following format:
      GITHUB_CLIENT_ID=...
      GITHUB_CLIENT_SECRET=...
    '';
  };
  # https://github.com/settings/applications/2352617
  services.hedgedoc.environmentFile =
    config.clan.core.facts.services.hedgedoc-github-auth.secret."hedgedoc.env".path;
}
