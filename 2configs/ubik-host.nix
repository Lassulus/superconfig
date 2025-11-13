{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.ubik = {
    sshKey = config.clan.core.vars.generators.ubik-container.files."ubik.sync.key".path;
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#ubik switch --no-write-lock-file
    '';
  };
  clan.core.vars.generators.ubik-container = {
    files."ubik.sync.key" = { };
    migrateFact = "ubik-container";
    prompts.warn = {
      description = "copy or reference the secret key from the container into here, so we can actually start/sync the container";
      type = "hidden";
    };
  };
  containers.ubik.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/ubik/state";
    isReadOnly = false;
  };
  containers.ubik.bindMounts."/var/lib/nextcloud/data" = {
    hostPath = "/var/ubik";
    isReadOnly = false;
  };
  # services.nginx.virtualHosts."c.apanowicz.de" = {
  #   enableACME = true;
  #   acmeFallbackHost = "ubik.r";
  #   forceSSL = true;
  #   locations."/" = {
  #     recommendedProxySettings = true;
  #     proxyWebsockets = true;
  #     proxyPass = "https://ubik.r";
  #     extraConfig = ''
  #       client_max_body_size 9001M;
  #       # fix abort after 1GB download
  #       # https://trac.nginx.org/nginx/ticket/1472
  #       proxy_max_temp_file_size 0;
  #     '';
  #   };
  # };
  # services.nginx.virtualHosts."mail.ubikmedia.eu" = {
  #   enableACME = true;
  #   forceSSL = true;
  #   acmeFallbackHost = "ubik.r";
  #   locations."/" = {
  #     recommendedProxySettings = true;
  #     proxyWebsockets = true;
  #     proxyPass = "https://ubik.r";
  #   };
  # };

  services.nginx.virtualHosts."karlaskop.de" = {
    serverAliases = [ "www.karlaskop.de" ];
    enableACME = true;
    forceSSL = true;
    acmeFallbackHost = "prism.r";
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "https://prism.r";
    };
  };
}
