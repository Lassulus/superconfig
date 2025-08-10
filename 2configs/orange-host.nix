{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.orange = {
    sshKey = config.clan.core.vars.generators.orange-container.files."orange.sync.key".path;
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#orange switch --no-write-lock-file
    '';
  };
  containers.orange.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/orange/state";
    isReadOnly = false;
  };
  services.nginx.virtualHosts."lassul.us" = {
    # enableACME = config.security;
    # forceSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "http://orange.r";
    };
  };
  clan.core.vars.generators.orange-container = {
    files."orange.sync.key" = { };
    migrateFact = "orange-container";
    prompts.warn = {
      description = "copy or reference the secret key from the container into here, so we can actually start/sync the container";
      type = "hidden";
    };
  };
}
